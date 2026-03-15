#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${ROOT_DIR}/images.manifest"
REGISTRY_ADDRESS="${REGISTRY_ADDRESS:-localhost:5000}"
REGISTRY_TLS_VERIFY="${REGISTRY_TLS_VERIFY:-false}"
SYNC_DEVCONTAINER=1
INCLUDE_ANCESTORS=1
INCLUDE_DESCENDANTS=1
DRY_RUN=0
VERSION_TAG=""
CHANGED_MODE=0
CHANGED_SINCE_REF=""
NO_SELECTION_MESSAGE=""

declare -a CHANGED_FILES=()
declare -a GLOBAL_TRIGGER_PATHS=(
	"images.manifest"
	"build-images.sh"
)

declare -a IMAGE_ORDER=()
declare -A IMAGE_CONTEXT=()
declare -A IMAGE_CONTAINERFILE=()
declare -A IMAGE_DEPENDENCIES=()
declare -A IMAGE_DEVCONTAINER=()
declare -A SELECTED_IMAGES=()
declare -A BUILT_IMAGES=()
declare -A VISITED_ANCESTORS=()
declare -A VISITED_DESCENDANTS=()
declare -A CHANGED_FILES_SET=()
declare -A SELECTION_REASONS=()

usage() {
	cat <<'EOF'
Usage: ./build-images.sh [options] [image ...]

Builds Podman images defined in images.manifest, pushes both latest and a version tag,
and rebuilds dependent child images automatically. Running it with no arguments
uses git change detection and only rebuilds affected images.

Options:
	--version TAG            Use an explicit semver tag, for example 1.0.4.
  --registry HOST:PORT     Override the registry address. Defaults to localhost:5000.
  --tls-verify true|false  Control podman push/pull TLS verification. Defaults to false.
	--changed                Select images from staged, unstaged, and untracked git changes.
	--changed-since REF      Select images changed since REF...HEAD, plus local working tree changes.
  --skip-ancestors         Do not include parent images of explicit targets.
  --skip-descendants       Do not include child images of explicit targets.
  --no-sync-devcontainer   Do not rewrite devcontainer.json image references.
  --dry-run                Print the resolved build plan without building.
  --help                   Show this message.

Examples:
	./build-images.sh --version 1.0.4
	./build-images.sh --version 1.0.4 dev-base
	./build-images.sh --changed
	./build-images.sh --changed-since origin/main
	./build-images.sh --skip-descendants python-dev
EOF
}

log() {
	printf '%s\n' "$*"
}

fail() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

require_podman() {
	command -v podman >/dev/null 2>&1 || fail "Podman CLI is required on PATH to build or push images"
}

normalize_bool() {
	case "$1" in
		true|false)
			printf '%s\n' "$1"
			;;
		*)
			fail "Expected 'true' or 'false', got '$1'"
			;;
	esac
}

validate_semver() {
	[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] \
		|| fail "Version tag must be semver, for example 1.0.4"
}

require_version_tag() {
	[[ -n "$VERSION_TAG" ]] || fail "Builds require --version with a semver tag, for example 1.0.4"
	validate_semver "$VERSION_TAG"
}

load_manifest() {
	[[ -f "$MANIFEST_FILE" ]] || fail "Manifest not found: $MANIFEST_FILE"

	while IFS='|' read -r name context containerfile dependencies devcontainer || [[ -n "${name}${context}${containerfile}${dependencies}${devcontainer}" ]]; do
		[[ -z "$name" ]] && continue
		[[ "$name" == \#* ]] && continue

		IMAGE_ORDER+=("$name")
		IMAGE_CONTEXT["$name"]="$context"
		IMAGE_CONTAINERFILE["$name"]="$containerfile"
		IMAGE_DEPENDENCIES["$name"]="$dependencies"
		IMAGE_DEVCONTAINER["$name"]="$devcontainer"
	done < "$MANIFEST_FILE"

	[[ ${#IMAGE_ORDER[@]} -gt 0 ]] || fail "Manifest is empty: $MANIFEST_FILE"
}

require_known_image() {
	local image_name="$1"
	[[ -n "${IMAGE_CONTEXT[$image_name]:-}" ]] || fail "Unknown image '$image_name'"
}

dependency_image_name() {
	printf '%s\n' "${1%%:*}"
}

dependency_arg_name() {
	printf '%s\n' "${1#*:}"
}

for_each_dependency() {
	local image_name="$1"
	local callback="$2"
	local dependency_list dependency

	dependency_list="${IMAGE_DEPENDENCIES[$image_name]}"
	[[ -z "$dependency_list" ]] && return 0

	IFS=',' read -r -a dependency_array <<< "$dependency_list"
	for dependency in "${dependency_array[@]}"; do
		[[ -n "$dependency" ]] || continue
		"$callback" "$image_name" "$dependency"
	done
}

mark_selected() {
	SELECTED_IMAGES["$1"]=1
}

append_reason() {
	local image_name="$1"
	local reason="$2"
	local current_reasons="${SELECTION_REASONS[$image_name]:-}"

	case "|$current_reasons|" in
		*"|$reason|"*)
			return 0
			;;
	esac

	if [[ -n "$current_reasons" ]]; then
		SELECTION_REASONS["$image_name"]+="|$reason"
	else
		SELECTION_REASONS["$image_name"]="$reason"
	fi
}

mark_selected_with_reason() {
	local image_name="$1"
	local reason="$2"

	mark_selected "$image_name"
	append_reason "$image_name" "$reason"
}

mark_ancestors_callback() {
	local _image_name="$1"
	local dependency="$2"
	local dependency_name

	dependency_name="$(dependency_image_name "$dependency")"
	mark_with_ancestors "$dependency_name"
}

mark_with_ancestors() {
	local image_name="$1"
	[[ "${VISITED_ANCESTORS[$image_name]:-0}" -eq 1 ]] && return 0
	VISITED_ANCESTORS["$image_name"]=1
	if [[ "${SELECTED_IMAGES[$image_name]:-0}" -ne 1 ]]; then
		mark_selected_with_reason "$image_name" "required ancestor"
	else
		append_reason "$image_name" "required ancestor"
	fi
	for_each_dependency "$image_name" mark_ancestors_callback
}

image_depends_on() {
	local image_name="$1"
	local candidate_parent="$2"
	local dependency_list dependency dependency_name

	dependency_list="${IMAGE_DEPENDENCIES[$image_name]}"
	[[ -z "$dependency_list" ]] && return 1

	IFS=',' read -r -a dependency_array <<< "$dependency_list"
	for dependency in "${dependency_array[@]}"; do
		dependency_name="$(dependency_image_name "$dependency")"
		if [[ "$dependency_name" == "$candidate_parent" ]]; then
			return 0
		fi
	done

	return 1
}

mark_with_descendants() {
	local image_name="$1"
	local candidate

	[[ "${VISITED_DESCENDANTS[$image_name]:-0}" -eq 1 ]] && return 0
	VISITED_DESCENDANTS["$image_name"]=1
	[[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]] || mark_selected_with_reason "$image_name" "dependent child"

	for candidate in "${IMAGE_ORDER[@]}"; do
		if image_depends_on "$candidate" "$image_name"; then
			if [[ "${SELECTED_IMAGES[$candidate]:-0}" -ne 1 ]]; then
				mark_selected_with_reason "$candidate" "dependent child"
			else
				append_reason "$candidate" "dependent child"
			fi
			mark_with_descendants "$candidate"
		fi
	done
}

git_file_lines() {
	local git_args=("$@")
	git -C "$ROOT_DIR" "${git_args[@]}" | while IFS= read -r line; do
		printf '%s\0' "$line"
	done
}

add_changed_file() {
	local relative_path="$1"
	[[ -n "$relative_path" ]] || return 0
	if [[ -z "${CHANGED_FILES_SET[$relative_path]:-}" ]]; then
		CHANGED_FILES_SET["$relative_path"]=1
		CHANGED_FILES+=("$relative_path")
	fi
}

collect_changed_files() {
	local changed_file
	local -a refs=()

	if [[ -n "$CHANGED_SINCE_REF" ]]; then
		git -C "$ROOT_DIR" rev-parse --verify "$CHANGED_SINCE_REF" >/dev/null 2>&1 || fail "Unknown git ref '$CHANGED_SINCE_REF'"
		while IFS= read -r -d '' changed_file; do
			add_changed_file "$changed_file"
		done < <(git_file_lines diff --name-only --diff-filter=ACMR "$CHANGED_SINCE_REF...HEAD")
	fi

	while IFS= read -r -d '' changed_file; do
		add_changed_file "$changed_file"
	done < <(git_file_lines diff --name-only --diff-filter=ACMR --cached)

	while IFS= read -r -d '' changed_file; do
		add_changed_file "$changed_file"
	done < <(git_file_lines diff --name-only --diff-filter=ACMR)

	while IFS= read -r -d '' changed_file; do
		add_changed_file "$changed_file"
	done < <(git_file_lines ls-files --others --exclude-standard)
}

is_global_trigger_path() {
	local relative_path="$1"
	local trigger_path

	for trigger_path in "${GLOBAL_TRIGGER_PATHS[@]}"; do
		if [[ "$relative_path" == "$trigger_path" ]]; then
			return 0
		fi
	done

	return 1
}

select_all_images_for_change() {
	local relative_path="$1"
	local image_name

	for image_name in "${IMAGE_ORDER[@]}"; do
		mark_selected_with_reason "$image_name" "global change: $relative_path"
		done
}

image_matches_changed_file() {
	local image_name="$1"
	local relative_path="$2"
	local context_prefix devcontainer_path containerfile_path

	context_prefix="${IMAGE_CONTEXT[$image_name]}/"
	devcontainer_path="${IMAGE_DEVCONTAINER[$image_name]}"
	containerfile_path="${IMAGE_CONTEXT[$image_name]}/${IMAGE_CONTAINERFILE[$image_name]}"

	if [[ "$relative_path" == "$containerfile_path" ]]; then
		return 0
	fi

	if [[ -n "$devcontainer_path" && "$relative_path" == "$devcontainer_path" ]]; then
		return 0
	fi

	if [[ "$relative_path" == "$context_prefix"* ]]; then
		return 0
	fi

	return 1
}

select_changed_images() {
	local changed_file image_name matches=0

	collect_changed_files

	if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
		NO_SELECTION_MESSAGE="No git changes detected. Nothing to build."
		return 0
	fi

	for changed_file in "${CHANGED_FILES[@]}"; do
		if is_global_trigger_path "$changed_file"; then
			select_all_images_for_change "$changed_file"
			matches=1
			continue
		fi

		for image_name in "${IMAGE_ORDER[@]}"; do
			if image_matches_changed_file "$image_name" "$changed_file"; then
				mark_selected_with_reason "$image_name" "changed file: $changed_file"
				matches=1
			fi
		done
	done

	if [[ "$matches" -ne 1 ]]; then
		NO_SELECTION_MESSAGE="No image-affecting changes detected. Nothing to build."
	fi
}

selected_count() {
	local image_name count=0

	for image_name in "${IMAGE_ORDER[@]}"; do
		if [[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]]; then
			count=$((count + 1))
		fi
	done

	printf '%s\n' "$count"
}

prepare_build_context() {
	local image_name="$1"

	case "$image_name" in
		dev-base)
			if [[ -f "${HOME}/.config/starship.toml" ]]; then
				cp -f "${HOME}/.config/starship.toml" "${ROOT_DIR}/dev-base/.starship.toml"
			fi
			;;
	esac
}

ensure_registry() {
	local registry_script="${ROOT_DIR}/dev-base/setup-local-registry.sh"
	[[ -x "$registry_script" ]] || fail "Registry setup script not executable: $registry_script"
	REGISTRY_ADDRESS="$REGISTRY_ADDRESS" "$registry_script"
}

registry_ref() {
	local image_name="$1"
	local tag="$2"
	printf '%s/%s:%s\n' "$REGISTRY_ADDRESS" "$image_name" "$tag"
}

sync_devcontainer_image() {
	local image_name="$1"
	local version_ref="$2"
	local devcontainer_path

	[[ "$SYNC_DEVCONTAINER" -eq 1 ]] || return 0

	devcontainer_path="${IMAGE_DEVCONTAINER[$image_name]}"
	[[ -n "$devcontainer_path" ]] || return 0
	devcontainer_path="${ROOT_DIR}/${devcontainer_path}"
	[[ -f "$devcontainer_path" ]] || fail "Devcontainer file not found: $devcontainer_path"

	perl -0pi -e 's|"image"\s*:\s*"[^"]+"|"image": "'"$version_ref"'"|' "$devcontainer_path"
	log "Updated ${devcontainer_path#${ROOT_DIR}/} -> $version_ref"
}

build_image() {
	local image_name="$1"
	local context_dir containerfile_path local_ref latest_ref version_ref dependency_list dependency
	local dependency_name dependency_arg dependency_tag
	local -a build_args=()

	context_dir="${ROOT_DIR}/${IMAGE_CONTEXT[$image_name]}"
	containerfile_path="${context_dir}/${IMAGE_CONTAINERFILE[$image_name]}"
	local_ref="${image_name}:latest"
	latest_ref="$(registry_ref "$image_name" latest)"
	version_ref="$(registry_ref "$image_name" "$VERSION_TAG")"

	[[ -d "$context_dir" ]] || fail "Build context not found: $context_dir"
	[[ -f "$containerfile_path" ]] || fail "Containerfile not found: $containerfile_path"
	prepare_build_context "$image_name"

	dependency_list="${IMAGE_DEPENDENCIES[$image_name]}"
	if [[ -n "$dependency_list" ]]; then
		IFS=',' read -r -a dependency_array <<< "$dependency_list"
		for dependency in "${dependency_array[@]}"; do
			[[ -n "$dependency" ]] || continue
			dependency_name="$(dependency_image_name "$dependency")"
			dependency_arg="$(dependency_arg_name "$dependency")"
			if [[ "${BUILT_IMAGES[$dependency_name]:-0}" -eq 1 ]]; then
				dependency_tag="$VERSION_TAG"
			else
				dependency_tag="latest"
			fi
			build_args+=(--build-arg "${dependency_arg}=${dependency_tag}")
		done
	fi

	log "Building $image_name"
	podman build -f "$containerfile_path" -t "$local_ref" "${build_args[@]}" "$context_dir"

	log "Tagging $latest_ref"
	podman tag "$local_ref" "$latest_ref"
	log "Pushing $latest_ref"
	podman push --tls-verify="$REGISTRY_TLS_VERIFY" "$latest_ref"

	log "Tagging $version_ref"
	podman tag "$local_ref" "$version_ref"
	log "Pushing $version_ref"
	podman push --tls-verify="$REGISTRY_TLS_VERIFY" "$version_ref"

	BUILT_IMAGES["$image_name"]=1
	sync_devcontainer_image "$image_name" "$version_ref"
}

print_plan() {
	local image_name dependency_list dependency dependency_name dependency_tag reasons reason

	log "Registry: $REGISTRY_ADDRESS"
	log "Version tag: $VERSION_TAG"
	if [[ "$CHANGED_MODE" -eq 1 ]]; then
		if [[ -n "$CHANGED_SINCE_REF" ]]; then
			log "Change detection: $CHANGED_SINCE_REF...HEAD plus local changes"
		else
			log "Change detection: staged, unstaged, and untracked files"
		fi
		log "Changed files:"
		for reason in "${CHANGED_FILES[@]}"; do
			printf '  - %s\n' "$reason"
		done
	fi
	log "Build order:"
	for image_name in "${IMAGE_ORDER[@]}"; do
		[[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]] || continue
		printf '  - %s\n' "$image_name"
		reasons="${SELECTION_REASONS[$image_name]:-}"
		if [[ -n "$reasons" ]]; then
			IFS='|' read -r -a reason_array <<< "$reasons"
			for reason in "${reason_array[@]}"; do
				printf '      reason: %s\n' "$reason"
			done
		fi
		dependency_list="${IMAGE_DEPENDENCIES[$image_name]}"
		if [[ -n "$dependency_list" ]]; then
			IFS=',' read -r -a dependency_array <<< "$dependency_list"
			for dependency in "${dependency_array[@]}"; do
				dependency_name="$(dependency_image_name "$dependency")"
				if [[ "${SELECTED_IMAGES[$dependency_name]:-0}" -eq 1 ]]; then
					dependency_tag="$VERSION_TAG"
				else
					dependency_tag="latest"
				fi
				printf '      uses %s:%s via %s\n' "$dependency_name" "$dependency_tag" "$(dependency_arg_name "$dependency")"
			done
		fi
	done
}

parse_args() {
	local arg
	declare -ga REQUESTED_IMAGES=()

	while [[ $# -gt 0 ]]; do
		arg="$1"
		case "$arg" in
			--version)
				[[ $# -ge 2 ]] || fail "Missing value for --version"
				VERSION_TAG="$2"
				shift 2
				;;
			--registry)
				[[ $# -ge 2 ]] || fail "Missing value for --registry"
				REGISTRY_ADDRESS="$2"
				shift 2
				;;
			--tls-verify)
				[[ $# -ge 2 ]] || fail "Missing value for --tls-verify"
				REGISTRY_TLS_VERIFY="$(normalize_bool "$2")"
				shift 2
				;;
			--changed)
				CHANGED_MODE=1
				shift
				;;
			--changed-since)
				[[ $# -ge 2 ]] || fail "Missing value for --changed-since"
				CHANGED_MODE=1
				CHANGED_SINCE_REF="$2"
				shift 2
				;;
			--skip-ancestors)
				INCLUDE_ANCESTORS=0
				shift
				;;
			--skip-descendants)
				INCLUDE_DESCENDANTS=0
				shift
				;;
			--no-sync-devcontainer)
				SYNC_DEVCONTAINER=0
				shift
				;;
			--dry-run)
				DRY_RUN=1
				shift
				;;
			--help|-h)
				usage
				exit 0
				;;
			--*)
				fail "Unknown option '$arg'"
				;;
			*)
				REQUESTED_IMAGES+=("$arg")
				shift
				;;
		esac
	done

	if [[ -n "$VERSION_TAG" ]]; then
		validate_semver "$VERSION_TAG"
	fi
}

resolve_selection() {
	local requested_image image_name

	if [[ ${#REQUESTED_IMAGES[@]} -eq 0 && "$CHANGED_MODE" -eq 0 ]]; then
		CHANGED_MODE=1
	fi

	if [[ "$CHANGED_MODE" -eq 1 ]]; then
		select_changed_images
	fi

	if [[ ${#REQUESTED_IMAGES[@]} -eq 0 && "$CHANGED_MODE" -eq 0 ]]; then
		for image_name in "${IMAGE_ORDER[@]}"; do
			mark_selected_with_reason "$image_name" "default selection"
		done
		return 0
	fi

	for requested_image in "${REQUESTED_IMAGES[@]}"; do
		require_known_image "$requested_image"
		mark_selected_with_reason "$requested_image" "explicit target"
		if [[ "$INCLUDE_ANCESTORS" -eq 1 ]]; then
			for_each_dependency "$requested_image" mark_ancestors_callback
		fi
	done

	if [[ "$INCLUDE_DESCENDANTS" -eq 1 ]]; then
		if [[ "$CHANGED_MODE" -eq 1 && ${#REQUESTED_IMAGES[@]} -eq 0 ]]; then
			for image_name in "${IMAGE_ORDER[@]}"; do
				if [[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]]; then
					mark_with_descendants "$image_name"
				fi
			done
		fi
		for requested_image in "${REQUESTED_IMAGES[@]}"; do
			mark_with_descendants "$requested_image"
		done
	fi

	if [[ "$INCLUDE_ANCESTORS" -eq 1 && "$CHANGED_MODE" -eq 1 ]]; then
		for image_name in "${IMAGE_ORDER[@]}"; do
			if [[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]]; then
				for_each_dependency "$image_name" mark_ancestors_callback
			fi
		done
	fi
}

main() {
	local image_name selection_count

	load_manifest
	parse_args "$@"
	resolve_selection
	selection_count="$(selected_count)"

	if [[ "$selection_count" -eq 0 ]]; then
		log "Registry: $REGISTRY_ADDRESS"
		log "Version tag: $VERSION_TAG"
		if [[ "$CHANGED_MODE" -eq 1 ]]; then
			if [[ -n "$CHANGED_SINCE_REF" ]]; then
				log "Change detection: $CHANGED_SINCE_REF...HEAD plus local changes"
			else
				log "Change detection: staged, unstaged, and untracked files"
			fi
		fi
		log "${NO_SELECTION_MESSAGE:-Nothing selected.}"
		return 0
	fi

	print_plan

	if [[ "$DRY_RUN" -eq 1 ]]; then
		return 0
	fi

	require_version_tag
	require_podman
	ensure_registry
	for image_name in "${IMAGE_ORDER[@]}"; do
		[[ "${SELECTED_IMAGES[$image_name]:-0}" -eq 1 ]] || continue
		build_image "$image_name"
	done
}

main "$@"
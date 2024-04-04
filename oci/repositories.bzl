"""Repository rules for fetching external tools"""

load("@aspect_bazel_lib//lib:repositories.bzl", "register_copy_to_directory_toolchains", "register_coreutils_toolchains", "register_jq_toolchains", "register_yq_toolchains")
load("//oci/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//oci/private:versions.bzl", "CRANE_VERSIONS", "ZOT_VERSIONS")

LATEST_CRANE_VERSION = CRANE_VERSIONS.keys()[0]
LATEST_ZOT_VERSION = ZOT_VERSIONS.keys()[0]

CRANE_BUILD_TMPL = """\
# Generated by oci/repositories.bzl
load("@rules_oci//oci:toolchain.bzl", "registry_toolchain")
load("@rules_oci//oci:toolchain.bzl", "crane_toolchain")

crane_toolchain(
    name = "crane_toolchain", 
    crane = "{binary}",
    version = "{version}"
)

registry_toolchain(
    name = "registry_toolchain", 
    registry = "{binary}",
    launcher = "launcher.sh"
)
"""

def _crane_repo_impl(repository_ctx):
    platform = repository_ctx.attr.platform.replace("amd64", "x86_64")
    url = "https://github.com/google/go-containerregistry/releases/download/{version}/go-containerregistry_{platform}.tar.gz".format(
        version = repository_ctx.attr.crane_version,
        platform = platform[:1].upper() + platform[1:],
    )
    repository_ctx.download_and_extract(
        url = url,
        integrity = CRANE_VERSIONS[repository_ctx.attr.crane_version][platform],
    )
    binary = "crane.exe" if platform.startswith("windows_") else "crane"
    repository_ctx.template(
        "launcher.sh",
        repository_ctx.attr._launcher_tpl,
        substitutions = {
            "{{CRANE}}": binary,
        },
    )
    repository_ctx.file(
        "BUILD.bazel",
        CRANE_BUILD_TMPL.format(
            binary = binary,
            version = repository_ctx.attr.crane_version,
        ),
    )

crane_repositories = repository_rule(
    _crane_repo_impl,
    doc = "Fetch external tools needed for crane toolchain",
    attrs = {
        "crane_version": attr.string(mandatory = True, values = CRANE_VERSIONS.keys()),
        "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
        "_launcher_tpl": attr.label(default = "//oci/private/registry:crane_launcher.sh.tpl"),
    },
)

ZOT_BUILD_TMPL = """\
# Generated by container/repositories.bzl
load("@rules_oci//oci:toolchain.bzl", "registry_toolchain")
registry_toolchain(
    name = "zot_toolchain", 
    registry = "zot",
    launcher = "launcher.sh"
)
"""

def _zot_repo_impl(repository_ctx):
    platform = repository_ctx.attr.platform.replace("_", "-")
    url = "https://github.com/project-zot/zot/releases/download/{version}/zot-{platform}-minimal".format(
        version = repository_ctx.attr.zot_version,
        platform = platform,
    )
    repository_ctx.download(
        url = url,
        output = "zot",
        executable = True,
        integrity = ZOT_VERSIONS[repository_ctx.attr.zot_version][platform],
    )
    repository_ctx.template("launcher.sh", repository_ctx.attr._launcher_tpl)
    repository_ctx.file("BUILD.bazel", ZOT_BUILD_TMPL)

zot_repositories = repository_rule(
    _zot_repo_impl,
    doc = "Fetch external tools needed for zot toolchain",
    attrs = {
        "zot_version": attr.string(mandatory = True, values = ZOT_VERSIONS.keys()),
        "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
        "_launcher_tpl": attr.label(default = "//oci/private/registry:zot_launcher.sh.tpl"),
    },
)

# Wrapper macro around everything above, this is the primary API
def oci_register_toolchains(name, crane_version, zot_version = None, register = True):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "container_linux_amd64" -
      this repository is lazily fetched when node is needed for that platform.
    - create a repository exposing toolchains for each platform like "container_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "container7"
        crane_version: passed to each crane_repositories call
        zot_version: passed to each zot_repositories call
        register: whether to call through to native.register_toolchains.
            Should be True for WORKSPACE users, but false when used under bzlmod extension
    """
    register_yq_toolchains(register = register)
    register_jq_toolchains(register = register)
    register_coreutils_toolchains(register = register)
    register_copy_to_directory_toolchains(register = register)

    crane_toolchain_name = "{name}_crane_toolchains".format(name = name)
    crane_registry_toolchain_name = "{name}_crane_registry_toolchains".format(name = name)
    zot_toolchain_name = "{name}_zot_toolchains".format(name = name)

    for platform in PLATFORMS.keys():
        crane_repositories(
            name = "{name}_crane_{platform}".format(name = name, platform = platform),
            platform = platform,
            crane_version = crane_version,
        )

        if zot_version:
            zot_repositories(
                name = "{name}_zot_{platform}".format(name = name, platform = platform),
                platform = platform,
                zot_version = zot_version,
            )

        if register:
            native.register_toolchains("@{}//:{}_toolchain".format(crane_toolchain_name, platform))
            if zot_version:
                native.register_toolchains("@{}//:{}_toolchain".format(zot_toolchain_name, platform))
            else:
                native.register_toolchains("@{}//:{}_toolchain".format(crane_registry_toolchain_name, platform))

    toolchains_repo(
        name = crane_toolchain_name,
        toolchain_type = "@rules_oci//oci:crane_toolchain_type",
        # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
        toolchain = "@%s_crane_{platform}//:crane_toolchain" % name,
    )

    if zot_version:
        toolchains_repo(
            name = zot_toolchain_name,
            toolchain_type = "@rules_oci//oci:registry_toolchain_type",
            # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
            toolchain = "@%s_zot_{platform}//:zot_toolchain" % name,
        )
    else:
        toolchains_repo(
            name = crane_registry_toolchain_name,
            toolchain_type = "@rules_oci//oci:registry_toolchain_type",
            # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
            toolchain = "@%s_crane_{platform}//:registry_toolchain" % name,
        )

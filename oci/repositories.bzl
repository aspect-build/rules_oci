"""Repository rules for fetching external tools"""

load("@aspect_bazel_lib//lib:repositories.bzl", "register_copy_to_directory_toolchains", "register_coreutils_toolchains", "register_jq_toolchains", "register_yq_toolchains")
load("//oci/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//oci/private:versions.bzl", "CRANE_VERSIONS", "ST_VERSIONS", "ZOT_VERSIONS")

LATEST_CRANE_VERSION = CRANE_VERSIONS.keys()[0]
LATEST_ZOT_VERSION = ZOT_VERSIONS.keys()[0]

CRANE_BUILD_TMPL = """\
# Generated by container/repositories.bzl
load("@rules_oci//oci:toolchain.bzl", "crane_toolchain")
crane_toolchain(
    name = "crane_toolchain", 
    crane = select({
        "@bazel_tools//src/conditions:host_windows": "crane.exe",
        "//conditions:default": "crane",
    }),
)
"""

def _crane_repo_impl(repository_ctx):
    url = "https://github.com/google/go-containerregistry/releases/download/{version}/go-containerregistry_{platform}.tar.gz".format(
        version = repository_ctx.attr.crane_version,
        platform = repository_ctx.attr.platform[:1].upper() + repository_ctx.attr.platform[1:],
    )
    repository_ctx.download_and_extract(
        url = url,
        integrity = CRANE_VERSIONS[repository_ctx.attr.crane_version][repository_ctx.attr.platform],
    )
    repository_ctx.file("BUILD.bazel", CRANE_BUILD_TMPL)

crane_repositories = repository_rule(
    _crane_repo_impl,
    doc = "Fetch external tools needed for crane toolchain",
    attrs = {
        "crane_version": attr.string(mandatory = True, values = CRANE_VERSIONS.keys()),
        "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
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
    platform = repository_ctx.attr.platform.replace("x86_64", "amd64").replace("_", "-")
    url = "https://github.com/project-zot/zot/releases/download/{version}/zot-{platform}".format(
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
        "_launcher_tpl": attr.label(default = "//oci/private:zot_launcher.sh.tpl"),
    },
)

STRUCTURE_TEST_BUILD_TMPL = """\
# Generated by container/repositories.bzl
load("@rules_oci//oci:toolchain.bzl", "structure_test_toolchain")
structure_test_toolchain(
    name = "structure_test_toolchain", 
    structure_test = "structure_test"
)
"""

def _stucture_test_repo_impl(repository_ctx):
    platform = repository_ctx.attr.platform.replace("x86_64", "amd64").replace("_", "-")

    # There is no arm64 version of structure test binary.
    # TODO: fix this upstream asking distroless people
    if platform.find("darwin") != -1:
        platform = platform.replace("arm64", "amd64")
    elif platform.find("windows") != -1:
        platform = platform + ".exe"
    url = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/{version}/container-structure-test-{platform}".format(
        version = repository_ctx.attr.st_version,
        platform = platform,
    )
    repository_ctx.download(
        url = url,
        output = "structure_test",
        integrity = ST_VERSIONS[repository_ctx.attr.st_version][platform],
        executable = True,
    )
    repository_ctx.file("BUILD.bazel", STRUCTURE_TEST_BUILD_TMPL)

structure_test_repositories = repository_rule(
    _stucture_test_repo_impl,
    doc = "Fetch external tools needed for zot toolchain",
    attrs = {
        "st_version": attr.string(mandatory = True, values = ST_VERSIONS.keys()),
        "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
    },
)

# Wrapper macro around everything above, this is the primary API
def oci_register_toolchains(name, crane_version, zot_version, register = True):
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
    zot_toolchain_name = "{name}_zot_toolchains".format(name = name)
    st_toolchain_name = "{name}_st_toolchains".format(name = name)

    for platform in PLATFORMS.keys():
        crane_repositories(
            name = "{name}_crane_{platform}".format(name = name, platform = platform),
            platform = platform,
            crane_version = crane_version,
        )

        zot_repositories(
            name = "{name}_zot_{platform}".format(name = name, platform = platform),
            platform = platform,
            zot_version = zot_version,
        )

        structure_test_repositories(
            name = "{name}_st_{platform}".format(name = name, platform = platform),
            platform = platform,
            # There are already too many version attributes. No need to expose this yet.
            st_version = ST_VERSIONS.keys()[0],
        )

        if register:
            native.register_toolchains("@{}//:{}_toolchain".format(crane_toolchain_name, platform))
            native.register_toolchains("@{}//:{}_toolchain".format(zot_toolchain_name, platform))
            native.register_toolchains("@{}//:{}_toolchain".format(st_toolchain_name, platform))

    toolchains_repo(
        name = crane_toolchain_name,
        toolchain_type = "@rules_oci//oci:crane_toolchain_type",
        # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
        toolchain = "@%s_crane_{platform}//:crane_toolchain" % name,
    )

    toolchains_repo(
        name = zot_toolchain_name,
        toolchain_type = "@rules_oci//oci:registry_toolchain_type",
        # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
        toolchain = "@%s_zot_{platform}//:zot_toolchain" % name,
    )

    toolchains_repo(
        name = st_toolchain_name,
        toolchain_type = "@rules_oci//oci:st_toolchain_type",
        # avoiding use of .format since {platform} is formatted by toolchains_repo for each platform.
        toolchain = "@%s_st_{platform}//:structure_test_toolchain" % name,
    )

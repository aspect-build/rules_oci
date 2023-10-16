<!-- Generated with Stardoc: http://skydoc.bazel.build -->

A repository rule to pull image layers using Bazel's downloader.

Typical usage in `WORKSPACE.bazel`:

```starlark
load("@rules_oci//oci:pull.bzl", "oci_pull")

# A single-arch base image
oci_pull(
    name = "distroless_java",
    digest = "sha256:161a1d97d592b3f1919801578c3a47c8e932071168a96267698f4b669c24c76d",
    image = "gcr.io/distroless/java17",
)

# A multi-arch base image
oci_pull(
    name = "distroless_static",
    digest = "sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12",
    image = "gcr.io/distroless/static",
    platforms = [
        "linux/amd64",
        "linux/arm64",
    ],
)
```

Now you can refer to these as a base layer in `BUILD.bazel`.
The target is named the same as the external repo, so you can use a short label syntax:

```
oci_image(
    name = "app",
    base = "@distroless_static",
    ...
)
```


<a id="oci_pull"></a>

## oci_pull

<pre>
oci_pull(<a href="#oci_pull-name">name</a>, <a href="#oci_pull-image">image</a>, <a href="#oci_pull-repository">repository</a>, <a href="#oci_pull-registry">registry</a>, <a href="#oci_pull-platforms">platforms</a>, <a href="#oci_pull-digest">digest</a>, <a href="#oci_pull-tag">tag</a>, <a href="#oci_pull-reproducible">reproducible</a>, <a href="#oci_pull-is_bzlmod">is_bzlmod</a>)
</pre>

Repository macro to fetch image manifest data from a remote docker registry.

To use the resulting image, you can use the `@wkspc` shorthand label, for example
if `name = "distroless_base"`, then you can just use `base = "@distroless_base"`
in rules like `oci_image`.

&gt; This shorthand syntax is broken on the command-line prior to Bazel 6.2.
&gt; See https://github.com/bazelbuild/bazel/issues/4385


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="oci_pull-name"></a>name |  repository with this name is created   |  none |
| <a id="oci_pull-image"></a>image |  the remote image, such as <code>gcr.io/bazel-public/bazel</code>. A tag can be suffixed with a colon, like <code>debian:latest</code>, and a digest can be suffixed with an at-sign, like <code>debian@sha256:e822570981e13a6ef1efcf31870726fbd62e72d9abfdcf405a9d8f566e8d7028</code>.<br><br>Exactly one of image or {registry,repository} should be set.   |  <code>None</code> |
| <a id="oci_pull-repository"></a>repository |  the image path beneath the registry, such as <code>distroless/static</code>. When set, registry must be set as well.   |  <code>None</code> |
| <a id="oci_pull-registry"></a>registry |  the remote registry domain, such as <code>gcr.io</code> or <code>docker.io</code>. When set, repository must be set as well.   |  <code>None</code> |
| <a id="oci_pull-platforms"></a>platforms |  for multi-architecture images, a dictionary of the platforms it supports This creates a separate external repository for each platform, avoiding fetching layers.   |  <code>None</code> |
| <a id="oci_pull-digest"></a>digest |  the digest string, starting with "sha256:", "sha512:", etc. If omitted, instructions for pinning are provided.   |  <code>None</code> |
| <a id="oci_pull-tag"></a>tag |  a tag to choose an image from the registry. Exactly one of <code>tag</code> and <code>digest</code> must be set. Since tags are mutable, this is not reproducible, so a warning is printed.   |  <code>None</code> |
| <a id="oci_pull-reproducible"></a>reproducible |  Set to False to silence the warning about reproducibility when using <code>tag</code>.   |  <code>True</code> |
| <a id="oci_pull-is_bzlmod"></a>is_bzlmod |  whether the oci_pull is being called from a module extension   |  <code>False</code> |



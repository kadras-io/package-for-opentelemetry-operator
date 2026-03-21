# Verifying the Package Release

This package is published as an OCI artifact, signed with Sigstore [Cosign](https://docs.sigstore.dev/cosign/overview), and associated with a [SLSA Provenance](https://slsa.dev/provenance) attestation.

Using `cosign`, you can display the supply chain security related artifacts for the `ghcr.io/kadras-io/package-for-opentelemetry-operator` images. Use the specific digest you'd like to verify.

```shell
cosign tree ghcr.io/kadras-io/package-for-opentelemetry-operator
```

The result:

```shell
📦 Supply Chain Security Related artifacts for an image: ghcr.io/kadras-io/package-for-opentelemetry-operator
└── 💾 Attestations for an image tag: ghcr.io/kadras-io/package-for-opentelemetry-operator:sha256-b7b13bbf52581f722c23819000aa3cfe01f78d59038d7069af25bbfe4a5491be.att
   └── 🍒 sha256:0710c13e9738b2a9c718eb7646c4fa9e3fc0a905a6992461b62b703ccae66974
└── 🔐 Signatures for an image tag: ghcr.io/kadras-io/package-for-opentelemetry-operator:sha256-b7b13bbf52581f722c23819000aa3cfe01f78d59038d7069af25bbfe4a5491be.sig
   └── 🍒 sha256:3f3b64a6f63c382ec1776b5962d74411fa51669e148f073ab28700cf5e10eab4
```

You can verify the signature and its claims:

```shell
cosign verify \
   --certificate-identity-regexp https://github.com/kadras-io \
   --certificate-oidc-issuer https://token.actions.githubusercontent.com \
   ghcr.io/kadras-io/package-for-opentelemetry-operator | jq
```

You can also verify the SLSA Provenance attestation associated with the image.

```shell
cosign verify-attestation --type slsaprovenance \
   --certificate-identity-regexp https://github.com/slsa-framework \
   --certificate-oidc-issuer https://token.actions.githubusercontent.com \
   ghcr.io/kadras-io/package-for-opentelemetry-operator | jq .payload -r | base64 --decode | jq
```

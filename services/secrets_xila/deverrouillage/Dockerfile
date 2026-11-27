# Unseals OpenBao with the unseal keys that Bruxelles' TPM keeps sealed (see
# deverrouillage.sh). The official images have no TPM tools: this one adds
# them to Alpine. tpm2-tss-tcti-device lets them reach the TPM through
# /dev/tpmrm0
FROM alpine:3.24.4

RUN apk add --no-cache tpm2-tools tpm2-tss-tcti-device curl jq

COPY --chmod=0755 deverrouillage.sh /usr/local/bin/deverrouillage.sh

ENTRYPOINT ["/usr/local/bin/deverrouillage.sh"]

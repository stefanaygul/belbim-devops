# certs

Bu klasördeki dosyalar `make certs` ile üretilir ve repoya girmez.

| Dosya | İçerik |
|---|---|
| `ca.crt` | Lab CA'sının sertifikası. Makinelere dağıtılan dosya budur. |
| `ca.key` | Lab CA'sının özel anahtarı. Paylaşılmaz. |
| `server.crt`, `server.key` | `gitlab`, `jenkins`, `sonar`, `nexus` adları için servis sertifikası. |

CA yalnızca `LAB_DOMAIN` altındaki adlar için sertifika imzalayabilir (`nameConstraints`).

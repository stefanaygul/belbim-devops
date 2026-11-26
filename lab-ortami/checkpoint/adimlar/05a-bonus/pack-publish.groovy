    // Bonus (LAB 05-A): paket yalnizca main'de ve yalnizca paket klasoru degistiyse yayinlanir.
    // Surum Nexus'ta zaten varsa stage anlasilir bir mesajla durur (main kirmizi olur):
    // paket degisti ama Version artirilmadi demektir. environment: NEXUS = 'https://nexus.kurum.test'
    // nuget-config: yoneticinin tanimladigi ortak NuGet.config (nexus = group, nexus-hosted = hosted).
    stage('Pack & Publish') {
      when { allOf { branch 'main'; changeset 'src/common-contracts/**' } }
      steps {
        configFileProvider([configFile(fileId: 'nuget-config', variable: 'NUGET_CFG')]) {
          withCredentials([string(credentialsId: 'nexus-nuget-key', variable: 'KEY')]) {
            sh '''rm -rf out && dotnet pack src/common-contracts -c Release -o out
                  PAKET=$(dotnet msbuild src/common-contracts -getProperty:PackageId)
                  SURUM=$(dotnet msbuild src/common-contracts -getProperty:Version)
                  ADRES="$NEXUS/repository/nuget-group/v3/content/$(echo $PAKET | tr 'A-Z' 'a-z')/index.json"
                  if curl -fsS "$ADRES" 2>/dev/null | grep -q "\\"$SURUM\\""; then
                    echo "HATA: $PAKET $SURUM Nexus'ta zaten var. src/common-contracts değişti ama Version artırılmadı; yayınlanmış sürüm değiştirilemez."
                    exit 1
                  fi
                  dotnet nuget push out/$PAKET.$SURUM.nupkg --configfile "$NUGET_CFG" --source nexus-hosted --api-key "$KEY"'''
          }
        }
      }
    }

# BELBIM DevOps egitimi - lab ortami
# Kullanim: make up && make bootstrap
SHELL := /bin/bash
.DEFAULT_GOAL := yardim

export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

COMPOSE := docker compose
TUM     := --profile cekirdek --profile ci --profile araclar
ARACLAR := $(COMPOSE) run --rm -T araclar

.PHONY: yardim env certs build up up-ci bekle bootstrap parolalar durum dogrula dogrula-ci dogrula-lab prova onkontrol checkpoint rol-degistir temel-imaj-paketi dur sifirla-ekip yik

yardim:
	@echo "make up            cekirdek ortami baslatir (GitLab, Nexus, workstation, test-vm)"
	@echo "make up-ci         CI profilini de baslatir (Jenkins, agent, SonarQube)"
	@echo "make bootstrap     gruplari, kullanicilari, depolari ve temel imajlari kurar (idempotent)"
	@echo "make parolalar     ekip hesaplarini ve parolalarini ekrana yazar"
	@echo "make durum         servis durumu ve kaynak kullanimi"
	@echo "make dogrula       cekirdek ortam denetimleri"
	@echo "make dogrula-ci    CI profili denetimleri (Jenkins, agent, SonarQube)"
	@echo "make dogrula-lab LAB=02-a EKIP=01   bir labin basari kriterlerini denetler"
	@echo "make onkontrol EKIP=01              katilimci makinesi on kontrolu (araclar, temel imajlar)"
	@echo "make checkpoint EKIP=01 LAB=final ekibi bir labin sonundaki duruma getirir (lab-01a ... final)"
	@echo "make prova         ekip-99 ile on lab (LAB 03-B deneme volumeu icin acik onay gerekli)"
	@echo "make rol-degistir EKIP=01           ekipte Maintainer/Developer rollerini degistirir (ASIL=1: geri al)"
	@echo "make temel-imaj-paketi DIZIN=...    temel imajlari baska makinelere tasimak icin .tar olarak yazar"
	@echo "make dur           container'lari durdurur (veri kalir)"
	@echo "make sifirla-ekip EKIP=01   bir ekibi baslangic durumuna dondurur"
	@echo "make yik           ortami ve TUM verisini siler (onay ister)"

env:
	@bash bootstrap/00-env.sh

build: env
	@$(COMPOSE) $(TUM) build

certs: env
	@$(COMPOSE) build -q araclar
	@$(COMPOSE) run --rm -T --no-deps araclar bash bootstrap/01-certs.sh

up: certs
	@$(COMPOSE) --profile cekirdek up -d --build
	@bash bootstrap/bekle.sh cekirdek

up-ci: certs
	@$(COMPOSE) --profile cekirdek --profile ci up -d --build
	@bash bootstrap/bekle.sh cekirdek ci

bekle:
	@bash bootstrap/bekle.sh cekirdek

bootstrap: env
	@bash bootstrap/bootstrap.sh

parolalar: env
	@$(ARACLAR) bash bootstrap/parolalar.sh

durum:
	@bash bootstrap/durum.sh

dogrula:
	@bash dogrula/cekirdek.sh

dogrula-ci:
	@bash dogrula/ci.sh

prova:
	@bash dogrula/prova.sh

dogrula-lab:
	@test -n "$(LAB)" -a -n "$(EKIP)" || { echo "Kullanim: make dogrula-lab LAB=02-a EKIP=01"; exit 2; }
	@bash dogrula/lab.sh "lab-$(LAB)" "$(EKIP)" $(if $(KAYNAK),KAYNAK=$(KAYNAK),)

onkontrol:
	@test -n "$(EKIP)" || { echo "Kullanim: make onkontrol EKIP=01"; exit 2; }
	@bash dogrula/lab.sh workstation-onkontrol "$(EKIP)"

checkpoint:
	@test -n "$(LAB)" -a -n "$(EKIP)" || { echo "Kullanim: make checkpoint EKIP=01 LAB=lab-02a"; exit 2; }
	@bash bootstrap/checkpoint-uygula.sh "$(EKIP)" "$(LAB)"

rol-degistir:
	@test -n "$(EKIP)" || { echo "Kullanim: make rol-degistir EKIP=01 [ASIL=1]"; exit 2; }
	@bash bootstrap/rol-degistir.sh "$(EKIP)" $(if $(ASIL),asil,degistir)

temel-imaj-paketi:
	@test -n "$(DIZIN)" || { echo "Kullanim: make temel-imaj-paketi DIZIN=/yol"; exit 2; }
	@bash bootstrap/35-workstation-imajlar.sh paket "$(DIZIN)"

dur:
	@$(COMPOSE) $(TUM) stop

sifirla-ekip:
	@test -n "$(EKIP)" || { echo "Kullanim: make sifirla-ekip EKIP=01"; exit 2; }
	@bash bootstrap/sifirla-ekip.sh "$(EKIP)"

yik:
	@echo "Bu islem belbim-lab projesinin TUM container ve volume'larini siler:"
	@$(COMPOSE) $(TUM) config --volumes | sed 's/^/  belbim-lab_/'
	@read -r -p "Devam etmek icin 'evet' yazin: " cevap && [ "$$cevap" = "evet" ] || { echo "Vazgecildi."; exit 1; }
	@$(COMPOSE) $(TUM) down --volumes --remove-orphans

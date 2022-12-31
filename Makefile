#!/usr/bin/make -f

cp := cp -afv
install := sudo install -DTv -m644
make := make --no-print-directory
mkdir := mkdir -p
wget := wget --no-config --quiet

home/files := $(shell git ls-files .config/ .gnupg/ .local/share/ bin/)
home/files += .bash_aliases .bash_completion .bashrc .profile
home/files += .inputrc .tmux.conf .wgetrc .xbindkeysrc develop/.clang-format
home/files := $(home/files:%=$(HOME)/%)

root/files := $(shell git ls-files etc/)
root/files := $(root/files:%=/%)

keyring/names := google microsoft slack surface
keyring/google := https://dl-ssl.google.com/linux/linux_signing_key.pub
keyring/microsoft := https://packages.microsoft.com/keys/microsoft.asc
keyring/slack := https://packagecloud.io/slacktechnologies/slack/gpgkey
keyring/surface := https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
keyring/ext := asc
keyring/files := $(keyring/names:%=/etc/apt/keyrings/%.$(keyring/ext))

.PHONY: install
install: install/home install/root

.PHONY: install/home
install/home: $(home/files)

$(home/files): $(HOME)/%: %
	@$(cp) --parents $< $(HOME)

.PHONY: install/root
install/root: $(root/files) $(keyring/files)

$(root/files): /%: %
	@$(install) $< $@

$(keyring/files):
	@echo Download $(@F)
	@sudo $(mkdir) $(@D)
	@sudo $(wget) -O $@ $(keyring/$(@F:%.$(keyring/ext)=%))

mkdir/$(HOME)/Private:
	mkdir -m 700 -p $(HOME)/Private

link/$(HOME)/.password-store:
	ln -s $(HOME)/Private/.password-store $(HOME)/.password-store

link/$(HOME)/Documents:
	ln -s $(HOME)/Dropbox/Documents $(HOME)/Documents

mkdir/tmp/$(USER):
	mkdir -m 700 -p /tmp/$(USER)
mkdir/tmp/$(USER)/Downloads:
	mkdir -m 700 -p /tmp/$(USER)/Downloads

link/tmp/$(USER)/Downloads:
	ln -s /tmp/$(USER)/Downloads $(HOME)/Downloads

mkdir/$(HOME)/.gnupg:
	mkdir -p $(HOME)/.gnupg
	chmod 700 $(HOME)/.gnupg

mkdir/$(HOME)/.local/share/tig:
	mkdir -p $(HOME)/.local/share/tig

linux-surface/packages := linux-image-surface linux-headers-surface iptsd libwacom-surface
install/linux-surface:
	sudo apt-get -qy update
	sudo apt-get -qy install $(linux-surface/packages)
	sudo systemctl enable iptsd
	sudo apt-get -qy install linux-surface-secureboot-mok

dropbox_url := https://www.dropbox.com/download?plat=lnx.x86_64
post-install:
	cd $(HOME) && wget -O - $(dropbox_url) | tar xzf -
	$(HOME)/.dropbox-dist/dropboxd
	im-config -n fcitx5
	sudo dconf update
	sudo apt-get -qy update
	sudo apt-get -qy install code google-chrome-stable slack-desktop
	sudo update-grub
	sudo localectl set-locale LANG=ja_JP.UTF-8

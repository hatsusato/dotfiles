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

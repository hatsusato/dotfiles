#!/usr/bin/make -f

cp := cp -afv
install := sudo install -DTv -m644
link := $(CURDIR)/link.sh
make := make --no-print-directory
mkdir := mkdir -p
wget := wget --no-config --quiet

dotfiles := .bash_aliases .bash_completion .bashrc .inputrc .profile .tmux.conf .wgetrc develop/.clang-format
home/files := $(shell git ls-files .config/) $(dotfiles)
home/target := $(home/files:%=$(HOME)/%)

root/files := $(shell git ls-files etc/)
root/target := $(root/files:%=/%)

keyring/google := https://dl-ssl.google.com/linux/linux_signing_key.pub
keyring/microsoft := https://packages.microsoft.com/keys/microsoft.asc
keyring/slack := https://packagecloud.io/slacktechnologies/slack/gpgkey
keyring/surface := https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc
keyring/files := google.asc microsoft.asc slack.asc surface.asc
keyring/dir := /etc/apt/keyrings
keyring/target := $(keyring/files:%=$(keyring/dir)/%)

.PHONY: install install/home install/root
install: install/home install/root

install/home: $(home/target)

$(home/target): $(HOME)/%: %
	@$(cp) --parents $< $(HOME)

install/root: $(root/target) $(keyring/target)

$(root/target): /%: %
	@$(install) $< $@

$(keyring/dir)/google.asc:
	@echo Download $(@F)
	@sudo $(mkdir) $(keyring/dir)
	@sudo $(wget) -O $@ $(keyring/google)
$(keyring/dir)/microsoft.asc:
	@echo Download $(@F)
	@sudo $(mkdir) $(keyring/dir)
	@sudo $(wget) -O $@ $(keyring/microsoft)
$(keyring/dir)/slack.asc:
	@echo Download $(@F)
	@sudo $(mkdir) $(keyring/dir)
	@sudo $(wget) -O $@ $(keyring/slack)
$(keyring/dir)/surface.asc:
	@echo Download $(@F)
	@sudo $(mkdir) $(keyring/dir)
	@sudo $(wget) -O $@ $(keyring/surface)


post/target := .password-store Documents Downloads

.PHONY: post-install $(post/target)
post-install:
	@$(make) $(post/target)
	im-config -n fcitx5
	sudo dconf update
	sudo update-grub

.password-store:
	@$(link) Private/$@ $(HOME)/$@
Documents:
	@$(link) Dropbox/$@ $(HOME)/$@
Downloads:
	@$(link) /tmp/$(USER)/$@ $(HOME)/$@

#!/usr/bin/make -f

cp := cp -afv
install := sudo install -DTv -m644
make := make --no-print-directory
mkdir := mkdir -p
wget := wget --no-config --quiet

dotfiles := .bash_aliases .bash_completion .bashrc .inputrc .password-store .profile .tmux.conf .wgetrc develop/.clang-format
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

home/dirs := Dropbox Private develop
home/dirs := $(home/dirs:%=$(HOME)/%)
home/link := Documents Downloads
home/link := $(home/link:%=$(HOME)/%)
script/dir := .local/bin/function

target := $(home/appends) $(home/dirs) $(home/copy) $(home/link)

.PHONY: install
install: $(home/target) $(root/target) $(keyring/target)

$(home/target): $(HOME)/%: %
	@$(cp) --parents $< $(HOME)

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

.PHONY: post-install
post-install:
	im-config -n fcitx5
	sudo dconf update
	sudo update-grub

#.PHONY: all
#all: $(target)
#
#$(home/appends): $(HOME)/%: %.append
#	@$(script/dir)/append.sh $< $@
#$(root/appends): /%: %.append
#	@$(script/dir)/append.sh $< $@
#$(home/dirs):
#	@mkdir -p $@
#$(home/copy): $(HOME)/%: %
#	@$(script/dir)/copy.sh $< $@
#$(root/copy): /%: %
#	@$(script/dir)/copy.sh $< $@
#$(HOME)/Documents:
#	@$(script/dir)/link.sh $(HOME)/Dropbox/Documents $@
#$(HOME)/Downloads:
#	@$(script/dir)/link.sh /tmp/$(USER)/Downloads $@
#
#.PHONY: chrome
#chrome/url := https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
#chrome/dir := /usr/local/src/$(USER)
#chrome/deb := $(chrome/dir)/$(notdir $(chrome/url))
#chrome: $(chrome/deb)
#	@dpkg -l google-chrome-stable 2>/dev/null | grep -q ^ii || \
#	sudo apt-get -qq install $<
#$(chrome/dir):
#	@sudo install -g $(USER) -o $(USER) -d $@
#$(chrome/deb): | $(chrome/dir)
#	@wget --no-verbose --show-progress -O $@ $(chrome/url)
#
#.PHONY: dropbox
#dropbox: $(HOME)/Documents $(HOME)/Dropbox
#	@$(script/dir)/apt.sh nautilus-dropbox
#	@dropbox start -i
#	@dropbox status
#	@dropbox status | grep -Fqx '最新の状態'

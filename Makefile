#!/usr/bin/make -f

make := make --no-print-directory

home/appends := .bashrc .profile
home/appends := $(home/appends:%=$(HOME)/%)
root/appends := /etc/default/grub
home/copy := $(shell find -L .config .emacs.d .local -type f)
home/copy += .bash_aliases .bash_completion .clang-format .inputrc .tmux.conf .wgetrc
home/copy := $(home/copy:%=$(HOME)/%)
root/copy := /etc/dconf/profile/user
home/dirs := Dropbox Private develop
home/dirs := $(home/dirs:%=$(HOME)/%)
home/emacs := $(shell find -L .emacs.d -type f)
home/emacs := $(home/emacs:%=$(HOME)/%)
home/link := .password-store Documents Downloads
home/link := $(home/links:%=$(HOME)/%)
home/xkb-notify := $(HOME)/.local/bin/xkb-notify

target := $(home/appends) $(home/dirs) $(home/copy) $(home/link) $(home/xkb-notify)

.PHONY: all
all: $(target)

$(home/appends): $(HOME)/%: %.append
	@./script/function/append.sh $< $@
$(root/appends): /%: %.append
	@./script/function/append.sh $< $@
$(home/dirs):
	@mkdir -p $@
$(home/copy): $(HOME)/%: %
	@./script/function/copy.sh $< $@
$(root/copy): /%: %
	@./script/function/copy.sh $< $@
$(HOME)/.password-store:
	@./script/function/link.sh $(HOME)/Private/.password-store
$(HOME)/Documents:
	@./script/function/link.sh $(HOME)/Dropbox/Documents $@
$(HOME)/Downloads:
	@./script/function/link.sh /tmp/$(USER)/Downloads $@
$(home/xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@

.PHONY: browserpass
browserpass/json := com.github.browserpass.native.json
browserpass/config := $(HOME)/.config/google-chrome/NativeMessagingHosts/$(browserpass/json)
browserpass/etc := /etc/chromium/native-messaging-hosts/$(browserpass/json)
browserpass: $(HOME)/.password-store $(browserpass/config)
$(browserpass/config): $(browserpass/etc)
$(browserpass/etc):
	@./script/function/apt.sh pass pwgen webext-browserpass

.PHONY: chrome
chrome/url := https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
chrome/dir := /usr/local/src/$(USER)
chrome/deb := $(chrome/dir)/$(notdir $(chrome/url))
chrome: $(chrome/deb)
	@./script/chrome-install.sh $<
$(chrome/dir):
	@sudo install -g $(USER) -o $(USER) -d $@
$(chrome/deb): | $(chrome/dir)
	@wget --no-verbose --show-progress -O $@ $(chrome/url)

.PHONY: dconf
dconf: $(HOME)/.config/dconf/user.txt /etc/dconf/profile/user
	@sudo dconf update

.PHONY: dropbox
dropbox: $(HOME)/Documents $(HOME)/Dropbox
	@./script/function/apt.sh nautilus-dropbox
	@dropbox start -i
	@dropbox status
	@dropbox status | grep -Fqx '最新の状態'

.PHONY: emacs
emacs/git := https://github.com/syl20bnr/spacemacs
emacs: $(HOME)/.spacemacs $(home/emacs)
$(HOME)/.emacs.d/.git:
	@test -d $@ || git clone --branch develop $(emacs/git) $(@D)
$(HOME)/.spacemacs: $(HOME)/.emacs.d/.git
	@./script/function/apt.sh emacs emacs-mozc
	@test -f $@ || emacs
$(home/emacs): $(HOME)/.emacs.d/.git

.PHONY: fcitx
fcitx/title := 'im-config instructions'
fcitx/message := '1. OK, 2. YES, 3. [x] fcitx -> OK, 4. OK'
fcitx: $(HOME)/.config/fcitx/config
	@./script/function/apt.sh fcitx fcitx-mozc
	@notify-send -u critical $(fcitx/title) $(fcitx/message)
	@im-config &>/dev/null

.PHONY: grub
grub: /etc/default/grub
	@sudo update-grub

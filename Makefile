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

chrome/deb := /usr/local/src/$(USER)/google-chrome-stable_current_amd64.deb
home/xkb-notify := $(HOME)/.local/bin/xkb-notify
browserpass/json := com.github.browserpass.native.json
browserpass/config := $(HOME)/.config/google-chrome/NativeMessagingHosts/$(browserpass/json)
browserpass/etc := /etc/chromium/native-messaging-hosts/$(browserpass/json)

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
browserpass: $(HOME)/.password-store $(browserpass/config)
$(browserpass/config): $(browserpass/etc)
$(browserpass/etc):
	@./script/function/apt.sh pass pwgen webext-browserpass

.PHONY: chrome
chrome: $(chrome/deb)
	@./script/chrome-install.sh $<
$(chrome/deb):
	@./script/chrome-download.sh $@

.PHONY: dconf
dconf: $(HOME)/.config/dconf/user.txt /etc/dconf/profile/user
	@sudo dconf update

.PHONY: dropbox
dropbox: $(HOME)/Documents $(HOME)/Dropbox
	@./script/function/apt.sh nautilus-dropbox
	@./script/dropbox-init.sh

.PHONY: emacs
emacs: $(HOME)/.spacemacs $(home/emacs)
$(HOME)/.emacs.d/.git:
	@./script/spacemacs-clone.sh
$(HOME)/.spacemacs: $(HOME)/.emacs.d/.git
	@./script/function/apt.sh emacs emacs-mozc
	@test -f $@ || emacs
$(home/emacs): $(HOME)/.emacs.d/.git

.PHONY: fcitx
fcitx: $(HOME)/.config/fcitx/config
	@./script/function/apt.sh fcitx fcitx-mozc
	@./script/fcitx-instruction.sh
	@im-config &>/dev/null

.PHONY: grub
grub: /etc/default/grub
	@sudo update-grub

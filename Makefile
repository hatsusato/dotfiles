#!/usr/bin/make -f

make := make --no-print-directory

home/appends := .bashrc .profile
home/appends := $(home/appends:%=$(HOME)/%)
root/appends := /etc/default/grub
home/dirs    := Dropbox Private develop
home/dirs    := $(home/dirs:%=$(HOME)/%)
home/emacs   := $(shell find -L .emacs.d -type f)
home/emacs   := $(home/emacs:%=$(HOME)/%)
home/install := $(shell find .config .emacs.d .local -type f)
home/install += .bash_aliases .bash_completion .clang-format .inputrc .wgetrc
home/install := $(home/install:%=$(HOME)/%)
root/install := /etc/dconf/profile/user
home/symlink := .password-store Documents Downloads
home/symlink := $(home/symlinks:%=$(HOME)/%)

chrome/deb := /usr/local/src/$(USER)/google-chrome-stable_current_amd64.deb
home/xkb-notify := $(HOME)/.local/bin/xkb-notify

target := $(home/appends) $(home/dirs) $(home/install) $(home/symlink) $(home/xkb-notify)

.PHONY: all
all: $(target)

$(home/appends): $(HOME)/%: %.append
	@./script/append.sh $< $@
$(root/appends): /%: %.append
	@./script/append.sh $< $@
$(home/dirs):
	@mkdir -p $@
$(home/install): $(HOME)/%: %
	@./script/install.sh $< $@
$(root/install): /%: %
	@./script/install.sh $< $@
$(HOME)/.password-store:
	@./script/link.sh $(HOME)/Private/.password-store
$(HOME)/Documents:
	@./script/link.sh $(HOME)/Dropbox/Documents $@
$(HOME)/Downloads:
	@./script/link.sh /tmp/$(USER)/Downloads $@
$(home/xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@

.PHONY: browserpass
browserpass: $(HOME)/.password-store $(HOME)/.config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json
	@./script/apt.sh pass pwgen
$(HOME)/.config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json: /etc/chromium/native-messaging-hosts/com.github.browserpass.native.json
	@./script/install.sh $< $@
/etc/chromium/native-messaging-hosts/com.github.browserpass.native.json:
	@./script/apt.sh webext-browserpass

.PHONY: chrome
chrome: $(chrome/deb)
	@./script/chrome.sh $<
$(chrome/deb):
	@./script/chrome-download.sh $@

.PHONY: dconf
dconf: $(HOME)/.config/dconf/user.txt /etc/dconf/profile/user
	@sudo dconf update

.PHONY: dropbox
dropbox: $(HOME)/Documents $(HOME)/Dropbox
	@./script/apt.sh nautilus-dropbox
	@dropbox start -i
	@dropbox status
	@dropbox status | grep -Fqx '最新の状態'

.PHONY: emacs emacs/update
emacs: $(HOME)/.emacs.d/.git $(home/emacs)
emacs/update:
	@git submodule update submodule/.emacs.d/private/hatsusato
$(home/emacs): emacs/update
$(HOME)/.emacs.d/.git:
	@./script/spacemacs.sh $(@D)

.PHONY: fcitx
fcitx: $(HOME)/.config/fcitx/config
	@./script/apt.sh fcitx fcitx-mozc
	@./script/fcitx-instruction.sh
	@im-config &>/dev/null

.PHONY: grub
grub: /etc/default/grub
	@sudo update-grub

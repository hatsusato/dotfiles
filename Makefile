#!/usr/bin/make -f

make := make --no-print-directory
modules := im-config spacemacs
xkb-notify := .local/bin/xkb-notify

appends := .bashrc .profile
home/appends := $(appends:%=$(HOME)/%)

files := $(shell find -L .config .local -type f)
home/files := $(files:%=$(HOME)/%)
install/files := $(files:%=install/%) install/$(xkb-notify)
emacs/private := $(shell find -L submodule/.emacs.d/private/hatsusato -type f)
home/emacs/private := $(emacs/private:submodule/%=$(HOME)/%)

.PHONY: all
all: $(home/files) $(home/appends) $(HOME)/$(xkb-notify)

$(home/appends): $(HOME)/%: %.append
	@./script/append.sh $< $@
$(home/files): $(HOME)/%: %
	@./script/install.sh $< $@
$(HOME)/$(xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@

.PHONY: $(install/files)
$(install/files): install/%: $(HOME)/%

.PHONY: $(modules)
$(modules):
	@./module/$@.sh

.PHONY: browserpass
browserpass: $(HOME)/.config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json
	@./script/apt.sh pass pwgen
$(HOME)/.config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json: /etc/chromium/native-messaging-hosts/com.github.browserpass.native.json
	@./script/install.sh $< $@
/etc/chromium/native-messaging-hosts/com.github.browserpass.native.json:
	@./script/apt.sh webext-browserpass

.PHONY: chrome
chrome: /usr/local/src/$(USER)/google-chrome-stable_current_amd64.deb
	@./script/chrome.sh $<
/usr/local/src/$(USER)/google-chrome-stable_current_amd64.deb:
	@./script/chrome-download.sh $@

.PHONY: dconf
dconf: $(HOME)/.config/dconf/user.txt /etc/dconf/profile/user
	@sudo dconf update
/etc/dconf/profile/user: /%: %
	@./script/install.sh $< $@

.PHONY: dropbox
dropbox:
	@./script/apt.sh nautilus-dropbox
	@dropbox start -i
	@dropbox status
	@dropbox status | grep -Fqx '最新の状態'

.PHONY: emacs
emacs: $(home/emacs/private)
$(HOME)/.emacs.d/.git:
	@./script/spacemacs.sh $(@D)
$(home/emacs/private): $(HOME)/%: submodule/% $(HOME)/.emacs.d/.git
	@./script/install.sh $< $@
$(emacs/private):
	@git submodule update $@

.PHONY: fcitx
fcitx: $(HOME)/.config/fcitx/config
	@./script/apt.sh fcitx fcitx-mozc
	@./script/fcitx-instruction.sh
	@im-config &>/dev/null

.PHONY: grub
grub: /etc/default/grub
	@sudo update-grub
/etc/default/grub: /%: %.append
	@./script/append.sh $< $@

$(HOME)/.gnupg/gpg-agent.conf: $(HOME)/%: %
	@./script/install.sh $< $@
/etc/X11/Xsession.options: /%: %.patch
	@./script/patch.sh $< $@

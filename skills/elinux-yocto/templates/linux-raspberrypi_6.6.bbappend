# Built-in (=y) sensor driver for linux-raspberrypi (meta-raspberrypi, scarthgap).
# Lives at: recipes-kernel/linux/linux-raspberrypi_6.6.bbappend in your layer.
# Named _6.6 on purpose: meta-raspberrypi ships linux-raspberrypi_6.1/_6.6/_6.12 and
# a '%' bbappend would also apply this 6.6 patch to the others (verified with
# bitbake-layers show-appends).
#
# Files next to this bbappend, in recipes-kernel/linux/files/:
#   0001-media-i2c-add-mycam-sensor-driver.patch   (git format-patch of the
#       scaffolded tree: driver + Kconfig + Makefile + overlay source +
#       overlays/Makefile entry; must apply to SRCREV_machine)
#   mycam.cfg                                     (config fragment, see below)
#
# Do NOT hard-code board values here; they belong in the patch's overlay/DT
# (TODO(board), TODO(datasheet) items).

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://0001-media-i2c-add-mycam-sensor-driver.patch \
    file://mycam.cfg \
"

# mycam.cfg must contain every symbol that makes the driver built-in:
#   CONFIG_VIDEO_MYCAM=y
#   CONFIG_VIDEO_DEV=y
#   CONFIG_V4L2_FWNODE=y
#   CONFIG_V4L2_CCI_I2C=y
# (bcm2711_defconfig has VIDEO_DEV and friends as =m, which would silently
# demote the driver to =m.) Verify the final config:
#   bitbake -c kernel_configcheck virtual/kernel
#   grep CONFIG_VIDEO_MYCAM ${B}/.config   (after do_configure)

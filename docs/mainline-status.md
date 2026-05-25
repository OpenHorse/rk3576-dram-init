RK3576 Mainline Kernel support
==============================

The RK3576 SoC (system on a chip), is similar to RK3588. Many hardware
blocks have been reused.

Explanation for the columns:

* Hardware: The block described by this line
* Issue: Optional link to an issue in Collabora's Gitlab about adding support for this hardware
* Driver: Hardware has a kernel driver with at least minimal support
* DT Binding: Hardware has a YAML based Devicetree binding
* RK3576 SoC DT: Hardware added in RK3576 Devicetree Source
* Sige5: Hardware added in ArmSom Sige5 Devicetree Source
* Rock 4D: Hardware added in the Radxa Rock 4D Devicetree Source

Explanation for the status:

* `n/a`: not available/applicable. For example the PMIC is not part of the SoC and thus does not belong into its DT
* WIP: work in progress - somebody is working on it
* sent: means a patch for this has been sent to the upstream mailing lists, a link is provided in the Notes column
* {+ v6.x-rc1 +} provides the first kernel version with support for this hardware
* {- TODO -} means, that we are not aware of anyone working on this

| Hardware                     | Driver         | DT Binding     | RK3576 SoC DT  | Sige5 DT       | Rock 4D DT     | Notes                                      |
| ------------------------     | -------------- | -------------- | -------------- | -------------- | -------------- | ------------------------------------------ |
| PMIC (rk806)                 | {+ 6.12-rc1 +} | {+ 6.5-rc1 +}  | `n/a`          | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| Real Time Clock (hym8563)    | {+ 3.14-rc1 +} | {+ 6.2-rc1 +}  | `n/a`          | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| Serial Audio Interface (SAI) | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | sent           | [PATCH v3](https://lore.kernel.org/all/20260408-rock4d-audio-v3-0-49e43c3c2a68@collabora.com/) |
| Audio Codec (es8316)         | {+ 4.13-rc1 +} | {+ 5.9-rc1 +}  | `n/a`          | `n/a`          | {- TODO -}     | Used on pre-production ROCK 4D only        |
| Audio Codec (es8388)         | {+ 4.11-rc1 +} | {+ 4.11-rc1 +} | `n/a`          | {+ 6.16-rc1 +} | sent           | [PATCH v3](https://lore.kernel.org/all/20260408-rock4d-audio-v3-0-49e43c3c2a68@collabora.com/) |
| SPDIF Audio Receiver         | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          | 400 line vendor driver, should be quick    |
| SPDIF Audio Transmitter      | {+ 5.15-rc1 +} | {+ 7.1-rc1 +}  | {+ 7.1-rc1 +}  | `n/a`          | `n/a`          | DONE                                       |
| LEDs                         | {+ 2.6.39 +}   | {+ 5.6-rc1 +}  | `n/a`          | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| WLAN (rtl8852bs)             | {- TODO -}     | {- TODO -}     | `n/a`          | {- TODO -}     | `n/a`          | only used by Sige5 v1.1; rtw89 supports chip generation, but not yet via sdio |
| Bluetooth (rtl8852bs)        | {+ 6.4-rc1 +}  | {- TODO -}     | `n/a`          | {- TODO -}     | `n/a`          | only used by Sige5 v1.1                    |
| WLAN (bcm4329-fmac)          | {+ 3.17-rc1 +} | {+ 3.17-rc1 +} | `n/a`          | {+ 6.17-rc1 +} | `n/a`          | only used by Sige5 v1.2; handled via overlay |
| Bluetooth (bcm43438-bt)      | {+ 4.14-rc1 +} | {+ 4.14-rc1 +} | `n/a`          | {+ 6.17-rc1 +} | `n/a`          | only used by Sige5 v1.2; handled via overlay |
| WLAN (AIC8800D80)            | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | 6.17-rc1       | DT is ready, but there is no upstream driver |
| Bluetooth (AIC8800D80)       | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | {- TODO -}     |                                            |
| clocks and resets (CRU)      | {+ 6.12-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| pmdomain                     | {+ 6.12-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| PHY naneng combphy           | {+ 6.14-rc1 +} | {+ 6.14-rc1 +} | {+ 6.14-rc1 +} | {+ 6.17-rc1 +} | {+ 6.17-rc1 +} | DONE                                       |
| PHY inno usb2                | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.14-rc1 +} | {+ 6.17-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| PHY usbdp                    | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.14-rc1 +} | {+ 6.17-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| PCIe2                        | {+ 5.15-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.17-rc1 +} | DONE                                       |
| cpufreq                      | `n/a`          | `n/a`          | {+ 6.13-rc1 +} | `n/a`          | `n/a`          |                                            |
| Ethernet                     | {+ 6.12-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| USB 3 DRD                    | {+ 3.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.14-rc1 +} | {+ 6.17-rc1 +} | {+ 6.15-rc1 +} | Type-C orientation handling needs [more work](https://lore.kernel.org/all/49eb73df-9a15-436e-a05c-72dd3aa36bf8@linaro.org/) |
| eMMC                         | {+ 6.0-rc1 +}  | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {- TODO -}     | DONE                                       |
| SD Card                      | {+ 6.12-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| SDIO                         | {+ 3.18-rc1 +} | {+ 6.12-rc1 +} | {+ 6.17-rc1 +} | {+ 6.17-rc1 +} | `n/a`          | DONE                                       |
| UFS                          | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | `n/a`          | {+ 6.17-rc1 +} | DONE                                       |
| SATA                         | {+ 6.1-rc1 +}  | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| Timer                        | {+ 5.0-rc1 +}  | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| **Display Controller (VOP)** | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} |                                            |
| - eDP                        | sent           | sent           | sent           |                |                | [PATCHv2](https://lore.kernel.org/linux-rockchip/20260319104031.1986946-1-damon.ding@rock-chips.com/) |
| - HDMI                       | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} |                                            |
| -- HDMI PHY                  | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| -- HDMI Bridge               | {+ 6.14-rc1 +} | {+ 6.14-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| -- HDMI Audio                | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.17-rc1 +} | DONE                                       |
| -- HDMI CEC                  | {+ 6.19-rc1 +} | `n/a`          | `n/a`          | `n/a`          | `n/a`          | DONE                                       |
| -- HDCP                      | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| - DSI                        | {+ 6.18-rc1 +} | {+ 6.18-rc1 +} | {+ 6.18-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| -- DSI PHY                   | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.18-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| -- DSI Bridge                | {+ 6.18-rc1 +} | {+ 6.18-rc1 +} | {+ 6.18-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| - DisplayPort                | {+ 7.1-rc1 +}  | {+ 7.1-rc1 +}  | {+ 7.1-rc1 +}  | {- TODO -}     | `n/a`          | DONE                                       |
|   - Audio                    | sent           | sent           | {- TODO -}     | {- TODO -}     | `n/a`          | [PATCHv2](https://lore.kernel.org/linux-rockchip/20260501-synopsys-dw-dp-improvements-v2-0-d7e7f6bac77f@collabora.com/) |
|   - MST                      | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          |                                            |
| - RGB                        | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          |                                            |
| HW crypto engine             | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          |                                            |
| Random Number Generator      | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | {+ 6.16-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| UART                         | {+ 3.2-rc1 +}  | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| GPIO                         | {+ 6.13-rc1 +} | {+ 5.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| Pinmux                       | {+ 6.12-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| Interrupts (GIC400)          | {+ 3.16-rc6 +} | {+ 5.1-rc1 +}  | {+ 6.13-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| PWM                          | sent           | sent           | sent           | {- TODO -}     | {- TODO -}     | [PATCHv5](https://lore.kernel.org/linux-rockchip/20260420-rk3576-pwm-v5-0-ae7cfbbe5427@collabora.com/) |
| SPI                          | {+ 3.17-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| I2C                          | {+ 4.8-rc1 +}  | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| I3C                          | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | new hardware, no downstream driver         |
| CAN                          | sent           | sent           | sent           | {- TODO -}     | {- TODO -}     | [PATCHv10](https://lore.kernel.org/linux-rockchip/20251118013929.2697132-1-zhangqing@rock-chips.com/) |
| FlexBUS                      | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          |                                            |
| SFC (Flash Controller)       | {+ 5.15-rc1 +} | {+ 5.15-rc1 +} | {+ 6.15-rc1 +} | {- TODO -}     | {- TODO -}     |                                            |
| OTP Memory                   | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | {+ 6.15-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| DFI                          | WIP            | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          | @fratti waiting on register map            |
| ADC                          | {+ 6.5-rc1 +}  | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {- TODO -}     | {- TODO -}     | DONE                                       |
| Thermal ADC                  | {+ 6.17-rc1 +} | {+ 6.17-rc1 +} | {+ 6.17-rc1 +} | {- TODO -}     | {- TODO -}     | Sige5 needs PWM for fan                    |
| Watchdog                     | {+ 3.13-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | `n/a`          | `n/a`          | DONE                                       |
| GPU (Mali G-52 MC3)          | {+ 5.10-rc1 +} | {+ 6.12-rc1 +} | {+ 6.13-rc1 +} | {+ 6.13-rc1 +} | {+ 6.15-rc1 +} | DONE                                       |
| NPU                          | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| ISP                          | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| RGA2                         | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| **Video Capture (VICAP)**    | {- TODO -}     | {- TODO -}     | `n/a`          | {- TODO -}     | {- TODO -}     |                                            |
| - MIPI CSI                   | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| **Media Encoders**           | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| - VEPU510                    | `n/a`          | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          | Presumably rkvenc                          |
| -- H.264/AVC                 | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| -- H.265/HEVC                | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| - VEPU720                    | `n/a`          | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          | Possibly not Hantro but their own IP?      |
| -- JPEG                      | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| **Media Decoders**           | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     | {- TODO -}     |                                            |
| - VDPU383                    | `n/a`          | {+ 6.18-rc1 +} | {+ 7.0-rc1 +}  | `n/a`          | `n/a`          | DONE                                       |
| -- H.264/AVC                 | {+ 7.0-rc1 +}  | `n/a`          | `n/a`          | `n/a`          | `n/a`          | DONE, missing multi-core support (see improvements section) |
| -- H.265/HEVC                | {+ 7.0-rc1 +}  | `n/a`          | `n/a`          | `n/a`          | `n/a`          | DONE, missing multi-core support (see improvements section) |
| -- VP9                       | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| -- AVS2                      | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| -- AV1                       | {- TODO -}     | `n/a`          | `n/a`          | `n/a`          | `n/a`          |                                            |
| - rkdjpeg                    | {- TODO -}     | {- TODO -}     | {- TODO -}     | `n/a`          | `n/a`          |                                            |

RK3576 Improvements (pending)
=============================

 * Thermal Sensor EPROBE_DEFER error: [PATCHv1](https://lore.kernel.org/all/20260317-rockchip-thermal-trim-warning-v1-1-01bc4bda75e9@collabora.com/)
 * VDPU383 multi-core support for H.264/H.265: [PATCHv1](https://lore.kernel.org/linux-media/20260409-rkvdec-multicore-v1-0-62b316abf0f7@collabora.com/)

RK3576 Improvements (merged)
=============================

 * SD detection fix: [PATCHv4](https://lore.kernel.org/linux-rockchip/1768524932-163929-1-git-send-email-shawn.lin@rock-chips.com/)
 * HDMI hotplug detection fix: [PATCHv1](https://lore.kernel.org/linux-rockchip/20260115-dw-hdmi-qp-hpd-v1-0-e59c166eaa65@collabora.com/)
 * Enable Watchdog by default: [PATCHv1](https://lore.kernel.org/linux-rockchip/20250818-rk3576-watchdog-v1-1-28f82e01029c@kernel.org/)
 * Fix Sige5 network DT description: [PATCHv1](https://lore.kernel.org/linux-rockchip/20250818-sige5-network-phy-clock-v1-1-87a9122d41c2@kernel.org/)
 * VOP2 output mode filtering: [PATCHv2](https://lore.kernel.org/linux-rockchip/20260117020738.294825-1-andyshrk@163.com/)
 * Sige5 stable SD/MMC device enumeration: [PATCHv1](https://lore.kernel.org/linux-rockchip/20260317-sige5-mmc-aliases-v1-1-ee93a1571802@collabora.com/)

Links
=====

 * [Downstream kernel](https://github.com/armbian/linux-rockchip/tree/rk3576-6.1-dev-2024_04_19)
 * [Downstream u-boot](https://github.com/ArmSoM/u-boot/tree/rk3576)
 * [rkbin firmwares](https://github.com/rockchip-linux/rkbin/)
 * [Sige 5 Board Info](https://docs.armsom.org/armsom-sige5)
 * [Collabora's Debian Images](https://gitlab.collabora.com/hardware-enablement/rockchip-3588/debian-image-recipes/-/jobs)
 * [RADXA's repository of the massive AIC8800 vendor driver](https://github.com/radxa-pkg/aic8800/)
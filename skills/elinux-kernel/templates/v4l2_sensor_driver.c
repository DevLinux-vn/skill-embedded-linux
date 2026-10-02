// SPDX-License-Identifier: GPL-2.0-only
/*
 * V4L2 raw-Bayer MIPI CSI-2 camera sensor driver -- TEMPLATE.
 *
 * Instantiate with skills/elinux-kernel/scripts/scaffold_sensor_driver.sh
 * (renames "mysensor"/"MYSENSOR"/"vendor" and wires Kconfig/Makefile for a
 * built-in or module build). Written against the kernel API of
 * raspberrypi/linux rpi-6.6.y (6.6.x): active subdev state, v4l2-cci helpers,
 * init_cfg pad op, i2c .probe with a single argument and void .remove.
 *
 * EVERY value tagged TODO(datasheet) or TODO(board) is deliberately left
 * unset. The driver fails probe with -ENODEV until MYSENSOR_CHIP_ID matches
 * the real chip, so an unfilled template cannot silently drive hardware.
 * Do not fill these in from memory: take them from the sensor datasheet and
 * the board schematic / the overlay actually used on the target.
 */

#include <linux/clk.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/pm_runtime.h>
#include <linux/regulator/consumer.h>

#include <media/v4l2-cci.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fwnode.h>
#include <media/v4l2-subdev.h>

/* ---- Registers: TODO(datasheet) ---------------------------------------- */
#define MYSENSOR_REG_CHIP_ID		CCI_REG16(0x0000) /* TODO(datasheet) */
#define MYSENSOR_CHIP_ID		0xffff		  /* TODO(datasheet) */
#define MYSENSOR_REG_MODE_SELECT	CCI_REG8(0x0000)  /* TODO(datasheet) */
#define MYSENSOR_MODE_STREAMING		0x01		  /* TODO(datasheet) */
#define MYSENSOR_MODE_STANDBY		0x00		  /* TODO(datasheet) */
#define MYSENSOR_REG_EXPOSURE		CCI_REG16(0x0000) /* TODO(datasheet) */
#define MYSENSOR_REG_ANALOG_GAIN	CCI_REG16(0x0000) /* TODO(datasheet) */
#define MYSENSOR_REG_VTS		CCI_REG16(0x0000) /* TODO(datasheet) */
#define MYSENSOR_REG_HTS		CCI_REG16(0x0000) /* TODO(datasheet) */

/* ---- Limits and timing: TODO(datasheet) / TODO(board) ------------------- */
#define MYSENSOR_XCLK_HZ		24000000	/* TODO(board): must match DT clock */
#define MYSENSOR_NATIVE_WIDTH		1280		/* TODO(datasheet) */
#define MYSENSOR_NATIVE_HEIGHT		720		/* TODO(datasheet) */
#define MYSENSOR_EXPOSURE_MIN		4		/* TODO(datasheet) */
#define MYSENSOR_EXPOSURE_STEP		1
#define MYSENSOR_GAIN_MIN		0		/* TODO(datasheet) */
#define MYSENSOR_GAIN_MAX		255		/* TODO(datasheet) */
#define MYSENSOR_GAIN_DEFAULT		16		/* TODO(datasheet) */
#define MYSENSOR_VTS_MAX		0xffff		/* TODO(datasheet) */
#define MYSENSOR_EXPOSURE_MARGIN	4		/* TODO(datasheet): exp <= vts - margin */
#define MYSENSOR_POWERUP_DELAY_US	10000		/* TODO(datasheet) */
#define MYSENSOR_SUSPEND_DELAY_MS	1000

/* TODO(datasheet): Bayer order and bit depth of the mode you register. */
#define MYSENSOR_MBUS_CODE		MEDIA_BUS_FMT_SRGGB10_1X10

static const char * const mysensor_supply_names[] = {
	"avdd", "dovdd", "dvdd",	/* TODO(board): names must match the DT binding */
};
#define MYSENSOR_NUM_SUPPLIES		ARRAY_SIZE(mysensor_supply_names)

/* Link frequency of the CSI-2 bus, Hz. TODO(datasheet): per mode PLL setup. */
static const s64 mysensor_link_freqs[] = { 400000000 };

struct mysensor_mode {
	u32 width;
	u32 height;
	u32 hts;		/* line length incl. blanking, pixels */
	u32 vts_def;		/* frame length default, lines */
	u32 vts_min;
	const struct cci_reg_sequence *regs;	/* mode-specific register writes */
	unsigned int num_regs;
	struct v4l2_rect crop;
};

/* TODO(datasheet): fill from the vendor register tables; keep them minimal. */
static const struct cci_reg_sequence mysensor_mode_regs[] = {
	{ CCI_REG8(0x0000), 0x00 },
};

static const struct mysensor_mode mysensor_modes[] = {
	{
		.width = MYSENSOR_NATIVE_WIDTH,
		.height = MYSENSOR_NATIVE_HEIGHT,
		.hts = 1600,		/* TODO(datasheet) */
		.vts_def = 800,		/* TODO(datasheet) */
		.vts_min = 750,		/* TODO(datasheet) */
		.regs = mysensor_mode_regs,
		.num_regs = ARRAY_SIZE(mysensor_mode_regs),
		.crop = { 0, 0, MYSENSOR_NATIVE_WIDTH, MYSENSOR_NATIVE_HEIGHT },
	},
};

struct mysensor {
	struct v4l2_subdev sd;
	struct media_pad pad;
	struct regmap *regmap;
	struct clk *xclk;
	struct gpio_desc *reset;
	struct regulator_bulk_data supplies[MYSENSOR_NUM_SUPPLIES];

	struct v4l2_ctrl_handler ctrls;
	struct v4l2_ctrl *pixel_rate;
	struct v4l2_ctrl *link_freq;
	struct v4l2_ctrl *hblank;
	struct v4l2_ctrl *vblank;
	struct v4l2_ctrl *exposure;

	const struct mysensor_mode *mode;
	bool streaming;
};

static inline struct mysensor *to_mysensor(struct v4l2_subdev *sd)
{
	return container_of(sd, struct mysensor, sd);
}

/* ---- Power ------------------------------------------------------------- */

static int mysensor_power_on(struct device *dev)
{
	struct v4l2_subdev *sd = dev_get_drvdata(dev);
	struct mysensor *s = to_mysensor(sd);
	int ret;

	/* TODO(datasheet): confirm supply -> clock -> reset ordering. */
	ret = regulator_bulk_enable(MYSENSOR_NUM_SUPPLIES, s->supplies);
	if (ret) {
		dev_err(dev, "failed to enable supplies: %d\n", ret);
		return ret;
	}

	ret = clk_prepare_enable(s->xclk);
	if (ret) {
		dev_err(dev, "failed to enable xclk: %d\n", ret);
		goto err_supplies;
	}

	gpiod_set_value_cansleep(s->reset, 0);	/* release reset (logical 0) */
	usleep_range(MYSENSOR_POWERUP_DELAY_US, MYSENSOR_POWERUP_DELAY_US + 1000);
	return 0;

err_supplies:
	regulator_bulk_disable(MYSENSOR_NUM_SUPPLIES, s->supplies);
	return ret;
}

static int mysensor_power_off(struct device *dev)
{
	struct v4l2_subdev *sd = dev_get_drvdata(dev);
	struct mysensor *s = to_mysensor(sd);

	gpiod_set_value_cansleep(s->reset, 1);
	clk_disable_unprepare(s->xclk);
	regulator_bulk_disable(MYSENSOR_NUM_SUPPLIES, s->supplies);
	return 0;
}

/* ---- Controls ---------------------------------------------------------- */

static void mysensor_update_exposure_limits(struct mysensor *s, u32 vts)
{
	u32 max = vts - MYSENSOR_EXPOSURE_MARGIN;

	__v4l2_ctrl_modify_range(s->exposure, MYSENSOR_EXPOSURE_MIN, max,
				 MYSENSOR_EXPOSURE_STEP,
				 min(s->exposure->val, (s32)max));
}

static int mysensor_s_ctrl(struct v4l2_ctrl *ctrl)
{
	struct mysensor *s = container_of(ctrl->handler, struct mysensor, ctrls);
	struct i2c_client *client = v4l2_get_subdevdata(&s->sd);
	int ret = 0;

	/* VBLANK changes the exposure ceiling even while powered down. */
	if (ctrl->id == V4L2_CID_VBLANK)
		mysensor_update_exposure_limits(s, s->mode->height + ctrl->val);

	/* Only touch hardware when it is powered; values replay on stream-on. */
	if (pm_runtime_get_if_in_use(&client->dev) == 0)
		return 0;

	switch (ctrl->id) {
	case V4L2_CID_EXPOSURE:
		cci_write(s->regmap, MYSENSOR_REG_EXPOSURE, ctrl->val, &ret);
		break;
	case V4L2_CID_ANALOGUE_GAIN:
		cci_write(s->regmap, MYSENSOR_REG_ANALOG_GAIN, ctrl->val, &ret);
		break;
	case V4L2_CID_VBLANK:
		cci_write(s->regmap, MYSENSOR_REG_VTS,
			  s->mode->height + ctrl->val, &ret);
		break;
	case V4L2_CID_HBLANK:	/* read-only here: fixed by the mode table */
	case V4L2_CID_PIXEL_RATE:
	case V4L2_CID_LINK_FREQ:
		break;
	default:
		ret = -EINVAL;
		break;
	}

	pm_runtime_put(&client->dev);
	return ret;
}

static const struct v4l2_ctrl_ops mysensor_ctrl_ops = {
	.s_ctrl = mysensor_s_ctrl,
};

static int mysensor_init_controls(struct mysensor *s)
{
	struct i2c_client *client = v4l2_get_subdevdata(&s->sd);
	const struct mysensor_mode *mode = s->mode;
	struct v4l2_fwnode_device_properties props;
	struct v4l2_ctrl_handler *hdl = &s->ctrls;
	u64 pixel_rate;
	int ret;

	v4l2_ctrl_handler_init(hdl, 9);

	/* pixel_rate = link_freq * 2 (DDR) * lanes / bits-per-pixel; TODO(datasheet) */
	pixel_rate = 80000000;
	s->pixel_rate = v4l2_ctrl_new_std(hdl, NULL, V4L2_CID_PIXEL_RATE,
					  pixel_rate, pixel_rate, 1, pixel_rate);

	s->link_freq = v4l2_ctrl_new_int_menu(hdl, NULL, V4L2_CID_LINK_FREQ,
					      ARRAY_SIZE(mysensor_link_freqs) - 1,
					      0, mysensor_link_freqs);
	if (s->link_freq)
		s->link_freq->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	s->hblank = v4l2_ctrl_new_std(hdl, &mysensor_ctrl_ops, V4L2_CID_HBLANK,
				      mode->hts - mode->width,
				      mode->hts - mode->width, 1,
				      mode->hts - mode->width);
	if (s->hblank)
		s->hblank->flags |= V4L2_CTRL_FLAG_READ_ONLY;

	s->vblank = v4l2_ctrl_new_std(hdl, &mysensor_ctrl_ops, V4L2_CID_VBLANK,
				      mode->vts_min - mode->height,
				      MYSENSOR_VTS_MAX - mode->height, 1,
				      mode->vts_def - mode->height);

	s->exposure = v4l2_ctrl_new_std(hdl, &mysensor_ctrl_ops,
					V4L2_CID_EXPOSURE, MYSENSOR_EXPOSURE_MIN,
					mode->vts_def - MYSENSOR_EXPOSURE_MARGIN,
					MYSENSOR_EXPOSURE_STEP,
					mode->vts_def - MYSENSOR_EXPOSURE_MARGIN);

	v4l2_ctrl_new_std(hdl, &mysensor_ctrl_ops, V4L2_CID_ANALOGUE_GAIN,
			  MYSENSOR_GAIN_MIN, MYSENSOR_GAIN_MAX, 1,
			  MYSENSOR_GAIN_DEFAULT);

	if (hdl->error) {
		ret = hdl->error;
		goto err_free;
	}

	/* rotation / orientation come from DT, not hard-coded here. */
	ret = v4l2_fwnode_device_parse(&client->dev, &props);
	if (ret)
		goto err_free;
	ret = v4l2_ctrl_new_fwnode_properties(hdl, &mysensor_ctrl_ops, &props);
	if (ret)
		goto err_free;

	s->sd.ctrl_handler = hdl;
	return 0;

err_free:
	v4l2_ctrl_handler_free(hdl);
	return ret;
}

/* ---- Pad operations ---------------------------------------------------- */

static int mysensor_enum_mbus_code(struct v4l2_subdev *sd,
				   struct v4l2_subdev_state *state,
				   struct v4l2_subdev_mbus_code_enum *code)
{
	if (code->index)
		return -EINVAL;
	code->code = MYSENSOR_MBUS_CODE;
	return 0;
}

static int mysensor_enum_frame_size(struct v4l2_subdev *sd,
				    struct v4l2_subdev_state *state,
				    struct v4l2_subdev_frame_size_enum *fse)
{
	if (fse->index >= ARRAY_SIZE(mysensor_modes) ||
	    fse->code != MYSENSOR_MBUS_CODE)
		return -EINVAL;

	fse->min_width = fse->max_width = mysensor_modes[fse->index].width;
	fse->min_height = fse->max_height = mysensor_modes[fse->index].height;
	return 0;
}

static void mysensor_fill_format(const struct mysensor_mode *mode,
				 struct v4l2_mbus_framefmt *fmt)
{
	fmt->code = MYSENSOR_MBUS_CODE;
	fmt->width = mode->width;
	fmt->height = mode->height;
	fmt->field = V4L2_FIELD_NONE;
	fmt->colorspace = V4L2_COLORSPACE_RAW;
	fmt->ycbcr_enc = V4L2_YCBCR_ENC_601;
	fmt->quantization = V4L2_QUANTIZATION_FULL_RANGE;
	fmt->xfer_func = V4L2_XFER_FUNC_NONE;
}

static int mysensor_init_cfg(struct v4l2_subdev *sd,
			     struct v4l2_subdev_state *state)
{
	mysensor_fill_format(&mysensor_modes[0],
			     v4l2_subdev_get_pad_format(sd, state, 0));
	*v4l2_subdev_get_pad_crop(sd, state, 0) = mysensor_modes[0].crop;
	return 0;
}

static int mysensor_set_fmt(struct v4l2_subdev *sd,
			    struct v4l2_subdev_state *state,
			    struct v4l2_subdev_format *fmt)
{
	struct mysensor *s = to_mysensor(sd);
	const struct mysensor_mode *mode;

	if (fmt->which == V4L2_SUBDEV_FORMAT_ACTIVE && s->streaming)
		return -EBUSY;

	mode = v4l2_find_nearest_size(mysensor_modes, ARRAY_SIZE(mysensor_modes),
				      width, height,
				      fmt->format.width, fmt->format.height);
	mysensor_fill_format(mode, &fmt->format);
	*v4l2_subdev_get_pad_format(sd, state, fmt->pad) = fmt->format;
	*v4l2_subdev_get_pad_crop(sd, state, fmt->pad) = mode->crop;

	if (fmt->which == V4L2_SUBDEV_FORMAT_ACTIVE && mode != s->mode) {
		s->mode = mode;
		__v4l2_ctrl_modify_range(s->vblank, mode->vts_min - mode->height,
					 MYSENSOR_VTS_MAX - mode->height, 1,
					 mode->vts_def - mode->height);
		__v4l2_ctrl_s_ctrl(s->vblank, mode->vts_def - mode->height);
		__v4l2_ctrl_modify_range(s->hblank, mode->hts - mode->width,
					 mode->hts - mode->width, 1,
					 mode->hts - mode->width);
		__v4l2_ctrl_s_ctrl(s->hblank, mode->hts - mode->width);
	}
	return 0;
}

static int mysensor_get_selection(struct v4l2_subdev *sd,
				  struct v4l2_subdev_state *state,
				  struct v4l2_subdev_selection *sel)
{
	switch (sel->target) {
	case V4L2_SEL_TGT_CROP:
		sel->r = *v4l2_subdev_get_pad_crop(sd, state, sel->pad);
		return 0;
	case V4L2_SEL_TGT_NATIVE_SIZE:
	case V4L2_SEL_TGT_CROP_BOUNDS:
	case V4L2_SEL_TGT_CROP_DEFAULT:
		sel->r = (struct v4l2_rect){ 0, 0, MYSENSOR_NATIVE_WIDTH,
					     MYSENSOR_NATIVE_HEIGHT };
		return 0;
	default:
		return -EINVAL;
	}
}

/* ---- Streaming --------------------------------------------------------- */

static int mysensor_start_streaming(struct mysensor *s,
				    struct v4l2_subdev_state *state)
{
	struct i2c_client *client = v4l2_get_subdevdata(&s->sd);
	int ret = 0;

	ret = pm_runtime_resume_and_get(&client->dev);
	if (ret < 0)
		return ret;

	ret = cci_multi_reg_write(s->regmap, s->mode->regs, s->mode->num_regs,
				  NULL);
	if (ret) {
		dev_err(&client->dev, "failed to program mode: %d\n", ret);
		goto err_rpm_put;
	}

	/* Replay user controls; ctrl lock == state lock, which we hold. */
	ret = __v4l2_ctrl_handler_setup(s->sd.ctrl_handler);
	if (ret)
		goto err_rpm_put;

	ret = cci_write(s->regmap, MYSENSOR_REG_MODE_SELECT,
			MYSENSOR_MODE_STREAMING, NULL);
	if (ret)
		goto err_rpm_put;

	/* Controls that must not change while streaming would be locked here. */
	return 0;

err_rpm_put:
	pm_runtime_put(&client->dev);
	return ret;
}

static void mysensor_stop_streaming(struct mysensor *s)
{
	struct i2c_client *client = v4l2_get_subdevdata(&s->sd);

	if (cci_write(s->regmap, MYSENSOR_REG_MODE_SELECT,
		      MYSENSOR_MODE_STANDBY, NULL))
		dev_err(&client->dev, "failed to stop streaming\n");
	pm_runtime_mark_last_busy(&client->dev);
	pm_runtime_put_autosuspend(&client->dev);
}

static int mysensor_s_stream(struct v4l2_subdev *sd, int enable)
{
	struct mysensor *s = to_mysensor(sd);
	struct v4l2_subdev_state *state;
	int ret = 0;

	state = v4l2_subdev_lock_and_get_active_state(sd);
	if (enable)
		ret = mysensor_start_streaming(s, state);
	else
		mysensor_stop_streaming(s);
	if (!ret)
		s->streaming = enable;
	v4l2_subdev_unlock_state(state);
	return ret;
}

static const struct v4l2_subdev_video_ops mysensor_video_ops = {
	.s_stream = mysensor_s_stream,
};

static const struct v4l2_subdev_pad_ops mysensor_pad_ops = {
	.init_cfg = mysensor_init_cfg,
	.enum_mbus_code = mysensor_enum_mbus_code,
	.enum_frame_size = mysensor_enum_frame_size,
	.get_fmt = v4l2_subdev_get_fmt,
	.set_fmt = mysensor_set_fmt,
	.get_selection = mysensor_get_selection,
};

static const struct v4l2_subdev_ops mysensor_subdev_ops = {
	.video = &mysensor_video_ops,
	.pad = &mysensor_pad_ops,
};

static const struct media_entity_operations mysensor_subdev_entity_ops = {
	.link_validate = v4l2_subdev_link_validate,
};

/* ---- Probe / remove ---------------------------------------------------- */

static int mysensor_check_endpoint(struct device *dev)
{
	struct v4l2_fwnode_endpoint ep = { .bus_type = V4L2_MBUS_CSI2_DPHY };
	struct fwnode_handle *fwnode;
	int ret;

	fwnode = fwnode_graph_get_next_endpoint(dev_fwnode(dev), NULL);
	if (!fwnode)
		return dev_err_probe(dev, -EINVAL, "no endpoint in DT\n");

	ret = v4l2_fwnode_endpoint_alloc_parse(fwnode, &ep);
	fwnode_handle_put(fwnode);
	if (ret)
		return dev_err_probe(dev, ret, "bad endpoint\n");

	/* TODO(datasheet): lanes the sensor supports; TODO(board): lanes wired. */
	if (ep.bus.mipi_csi2.num_data_lanes != 2 &&
	    ep.bus.mipi_csi2.num_data_lanes != 1) {
		ret = dev_err_probe(dev, -EINVAL, "unsupported lane count %u\n",
				    ep.bus.mipi_csi2.num_data_lanes);
		goto out;
	}

	if (!ep.nr_of_link_frequencies ||
	    ep.link_frequencies[0] != mysensor_link_freqs[0]) {
		ret = dev_err_probe(dev, -EINVAL,
				    "link-frequencies in DT must match driver\n");
		goto out;
	}
	ret = 0;
out:
	v4l2_fwnode_endpoint_free(&ep);
	return ret;
}

static int mysensor_identify(struct mysensor *s)
{
	struct i2c_client *client = v4l2_get_subdevdata(&s->sd);
	u64 id;
	int ret;

	ret = cci_read(s->regmap, MYSENSOR_REG_CHIP_ID, &id, NULL);
	if (ret)
		return dev_err_probe(&client->dev, ret, "chip ID read failed\n");
	if (id != MYSENSOR_CHIP_ID)
		return dev_err_probe(&client->dev, -ENODEV,
				     "unexpected chip ID 0x%04llx (template not filled in?)\n",
				     id);
	return 0;
}

static int mysensor_probe(struct i2c_client *client)
{
	struct device *dev = &client->dev;
	struct mysensor *s;
	unsigned int i;
	int ret;

	s = devm_kzalloc(dev, sizeof(*s), GFP_KERNEL);
	if (!s)
		return -ENOMEM;

	v4l2_i2c_subdev_init(&s->sd, client, &mysensor_subdev_ops);

	ret = mysensor_check_endpoint(dev);
	if (ret)
		return ret;

	s->regmap = devm_cci_regmap_init_i2c(client, 16);
	if (IS_ERR(s->regmap))
		return dev_err_probe(dev, PTR_ERR(s->regmap), "regmap init\n");

	s->xclk = devm_clk_get(dev, NULL);
	if (IS_ERR(s->xclk))
		return dev_err_probe(dev, PTR_ERR(s->xclk), "xclk\n");
	if (clk_get_rate(s->xclk) != MYSENSOR_XCLK_HZ)
		return dev_err_probe(dev, -EINVAL, "xclk must be %u Hz\n",
				     MYSENSOR_XCLK_HZ);

	for (i = 0; i < MYSENSOR_NUM_SUPPLIES; i++)
		s->supplies[i].supply = mysensor_supply_names[i];
	ret = devm_regulator_bulk_get(dev, MYSENSOR_NUM_SUPPLIES, s->supplies);
	if (ret)
		return dev_err_probe(dev, ret, "supplies\n");

	/* Optional: many camera boards drive reset/power-down from a regulator. */
	s->reset = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(s->reset))
		return dev_err_probe(dev, PTR_ERR(s->reset), "reset gpio\n");

	s->mode = &mysensor_modes[0];

	/* Power on by hand so we can identify, then hand over to runtime PM. */
	ret = mysensor_power_on(dev);
	if (ret)
		return ret;

	ret = mysensor_identify(s);
	if (ret)
		goto err_power_off;

	ret = mysensor_init_controls(s);
	if (ret)
		goto err_power_off;

	s->sd.flags |= V4L2_SUBDEV_FL_HAS_DEVNODE;
	s->sd.entity.function = MEDIA_ENT_F_CAM_SENSOR;
	s->sd.entity.ops = &mysensor_subdev_entity_ops;
	s->pad.flags = MEDIA_PAD_FL_SOURCE;
	ret = media_entity_pads_init(&s->sd.entity, 1, &s->pad);
	if (ret)
		goto err_free_ctrls;

	/* One lock for state and controls: see s_stream / set_fmt. */
	s->sd.state_lock = s->ctrls.lock;
	ret = v4l2_subdev_init_finalize(&s->sd);
	if (ret)
		goto err_entity_cleanup;

	pm_runtime_set_active(dev);
	pm_runtime_get_noresume(dev);
	pm_runtime_enable(dev);
	pm_runtime_set_autosuspend_delay(dev, MYSENSOR_SUSPEND_DELAY_MS);
	pm_runtime_use_autosuspend(dev);

	ret = v4l2_async_register_subdev_sensor(&s->sd);
	if (ret)
		goto err_pm;

	pm_runtime_mark_last_busy(dev);
	pm_runtime_put_autosuspend(dev);
	return 0;

err_pm:
	pm_runtime_disable(dev);
	pm_runtime_put_noidle(dev);
	v4l2_subdev_cleanup(&s->sd);
err_entity_cleanup:
	media_entity_cleanup(&s->sd.entity);
err_free_ctrls:
	v4l2_ctrl_handler_free(&s->ctrls);
err_power_off:
	mysensor_power_off(dev);
	return ret;
}

static void mysensor_remove(struct i2c_client *client)
{
	struct v4l2_subdev *sd = i2c_get_clientdata(client);
	struct mysensor *s = to_mysensor(sd);

	v4l2_async_unregister_subdev(sd);
	v4l2_subdev_cleanup(sd);
	media_entity_cleanup(&sd->entity);
	v4l2_ctrl_handler_free(&s->ctrls);

	pm_runtime_disable(&client->dev);
	if (!pm_runtime_status_suspended(&client->dev))
		mysensor_power_off(&client->dev);
	pm_runtime_set_suspended(&client->dev);
}

static DEFINE_RUNTIME_DEV_PM_OPS(mysensor_pm_ops, mysensor_power_off,
				 mysensor_power_on, NULL);

static const struct of_device_id mysensor_of_match[] = {
	{ .compatible = "vendor,mysensor" },	/* TODO: real vendor prefix */
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, mysensor_of_match);

static struct i2c_driver mysensor_i2c_driver = {
	.driver = {
		.name = "mysensor",
		.of_match_table = mysensor_of_match,
		.pm = pm_ptr(&mysensor_pm_ops),
	},
	.probe = mysensor_probe,
	.remove = mysensor_remove,
};
module_i2c_driver(mysensor_i2c_driver);

MODULE_DESCRIPTION("MYSENSOR CSI-2 camera sensor driver (template)");
MODULE_LICENSE("GPL");

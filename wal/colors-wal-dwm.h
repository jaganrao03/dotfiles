static const char norm_fg[] = "#e2cebe";
static const char norm_bg[] = "#090704";
static const char norm_border[] = "#9e9085";

static const char sel_fg[] = "#e2cebe";
static const char sel_bg[] = "#cf6117";
static const char sel_border[] = "#e2cebe";

static const char urg_fg[] = "#e2cebe";
static const char urg_bg[] = "#1313ae";
static const char urg_border[] = "#1313ae";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};

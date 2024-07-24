const char *colorname[] = {

  /* 8 normal colors */
  [0] = "#090704", /* black   */
  [1] = "#1313ae", /* red     */
  [2] = "#cf6117", /* green   */
  [3] = "#e88c35", /* yellow  */
  [4] = "#eb9c53", /* blue    */
  [5] = "#1c80e5", /* magenta */
  [6] = "#f0a681", /* cyan    */
  [7] = "#e2cebe", /* white   */

  /* 8 bright colors */
  [8]  = "#9e9085",  /* black   */
  [9]  = "#1313ae",  /* red     */
  [10] = "#cf6117", /* green   */
  [11] = "#e88c35", /* yellow  */
  [12] = "#eb9c53", /* blue    */
  [13] = "#1c80e5", /* magenta */
  [14] = "#f0a681", /* cyan    */
  [15] = "#e2cebe", /* white   */

  /* special colors */
  [256] = "#090704", /* background */
  [257] = "#e2cebe", /* foreground */
  [258] = "#e2cebe",     /* cursor */
};

/* Default colors (colorname index)
 * foreground, background, cursor */
 unsigned int defaultbg = 0;
 unsigned int defaultfg = 257;
 unsigned int defaultcs = 258;
 unsigned int defaultrcs= 258;

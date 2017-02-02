/*
 * V E G E T A B L E S
 * -------------------
 *
 * Experimental video edge detection system.
 *
 * Uses averaging over a square of pixels and checks changes in brightness
 * over a series of squares to find an edge. Colour coded horizontal and
 * vertical edge points and bright/dark area detection. Plots lines or curves
 * along edges which can be colour-coded to area brightness and open or
 * closed.
 * 
 * Allows editing of detection parameters in real-time, as well as toggling
 * various render modes and drawing options. Has the ability to pause the
 * video feed and still adjust the algorithm, for both real-time and recorded
 * frames being replayed. comprehensive display of status information with
 * full help text screen available for interactive features.
 *
 * TODO Fix 'a' key functionality
 *      - Missing out some dots in the detection list.
 *      - Most obvious with 'd' enabled and paused image, flip between 'a' on and
 *        off modes to see the effect. Probably just not including the entire array
 *        when creating line segments?
 *
 * Author: Andrew Donald Kennedy <andrew.international@gmail.com>
 * Created: 2009-08-19
 * Last-Modified: 2017-02-01, 2013-09-06
 * Version 0.7.4
 *
 * Copyright 2009-2017 by Andrew Kennedy; All Rights Reserved
 */

import processing.video.*;

// algorithm configuration parameters
int dt, bt, kt, ss, ds, s;
int ip[] = { // initial parameter set
   20, // diff threshold (intensity)
  100, // bright threshold (intensity)
   20, // same shape (px)
  100, // different shape (px)
    5  // averaged square dimension (px)
}, xp[] = { 12, 200, 15, 100, 3 }; // extra parameter set
int mp[][] = { ip, xp }, ps = 0; // choose parameters

void setParams(int[] pa) {
  dt = pa[0]; bt = pa[1]; kt = bt; ss = pa[2]; ds = pa[3]; s = pa[4];
}

int[] getParams() {
  int pa[] = { dt, bt, ss, ds, s }; return pa;
}

// screen size (px)
int scr[] = { 800, 600 }, w = scr[0], h = scr[1];        
// No Camera
// 800, 600
// Display iSight
// 80, 64
// 160, 128
// 320, 256
// 640, 512
// 1280, 1024
// FaceTime HD Camera
// 80, 45
// 160, 90
// 320, 180
// 640, 360
// 1280, 720

// application configuration settings
int as = 10;     // size of average buffer (number)
float q = 0.75;  // skip between squares ratio
float m = 1.25;  // dot radius multiplier
int fs = 15;     // font size (px)
float ce = 2.0;  // contrast enhancement

int cp = 100;

// mode properties (EDIT)
boolean v = true;   // show video image
boolean mk = false; // display marker circles
boolean sh = false; // show help text
boolean rd = false; // render dots
boolean rl = true;  // render lines
boolean cl = false; // draw curve or line
boolean cx = false; // closed or open curves
boolean ca = false; // all colours together
boolean gs = false; // grayscale

int si = 0; // info text modes (0/1/2) (EDIT)

// global variables
Capture video; // video capture library interface
boolean webcam = Capture.list().length > 0; // webcam exists?
boolean off = !webcam; // use webcam or offline frames
int sn = 0; // saved frame number
boolean sf = false; // save to file?
boolean rec = false; // record frames
boolean pp = false; // pause
PImage banner; // used to dim screen behind text
PImage src = new PImage(w, h), dst = new PImage(w, h); // pixel source image
int dc = 0, bc = 0, kc = 0, ec = 0; // count of dots
int bn = w * h; // max number of saved dots
int ex[] = new int[bn], ey[] = new int[bn]; // extra dots
int bx[] = new int[bn], by[] = new int[bn]; // bright dots
int kx[] = new int[bn], ky[] = new int[bn]; // dark dots
int a[]; // circular buffer for average brightnesses
int n = 0; // buffer pointer
int hd = 30, hc = 0; // help screen display duration
int of = 0, ot = 0, rf = 0; // offline frames
int ts = max(10, min(16, (int) (fs * (w / 800.0)))), tb = (int) (ts / 4.0); // text size and border

// colour and shade constants
color DIM = 0x64, BLACK = 0x00, WHITE = 0xff, FADE = #c8c8c8;
color RED = #f02040, YELLOW = #f0f070, GREEN = #109030, BLUE = #3020a0;
color CYAN = #407090, MAGENTA = #901060, LIGHT = 0xee;

// program information
String info[] = {
  "vegetables",
  "0.7.4",
  ts == 10 ? "eveds" : "experimental video edge detection system",
  "adk@abstractvisitorpattern.co.uk"
}, program = info[0], version = info[1], desc = info[2], email = info[3];

// help display text
String help[] = {
  program + " " + version,
  desc,
  "help for interactive key functions",
  " ",
  "change parameters",
  "1/2 - edge threshold",
  "3/4 - bright/dark threshold",
  "5/6 - cluster min radius",
  "7/8 - cluster min radius",
  "9/0 - averaging square size",
  "= - reset paramaters",
  " ",
  "toggle display modes",
  "i - information display",
  "m - marker circles",
  "v - video overlay and mirror display",
  "d - dot rendering",
  "l - line rendering",
  "c - edges as curves or lines",
  "x - closed or open curves",
  "a - all colours together",
  "g - colour or grayscale",
  " ",
  "control operation",
  "space - pause display",
  "enter - save current frame to disk",
  "r - record video for offline use",
  "o - toggle between webcam and offline",
  "q - exit the application",
  "h/? - show this help text",
  " ",
  email
};

// font choice list
String fonts[] = {
  // "Consolas", "Monaco", "Inconsolata", "Andale Mono", "Courier New", "Courier"
  // "Lucida Grande", "Century Gothic", "Verdana", "Helvetica", "Arial"
  "Inconsolata"
};

void cameraList() {
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
  } else {
    println("Available cameras:");
    for (int i = 0; i < cameras.length; i++) {
      println(cameras[i]);
    }
  }
}

/**
 * initial setup of screen, video and drawing properties
 */
void setup() {
  // cameraList(); // DEBUG
  
  // set initial parameters
  setParams(ip);
  
  // set size
  size(800, 600); // size must match w and h above

  // setup screen
  frameRate(5);
  noCursor();
  smooth();
  strokeJoin(ROUND);
  strokeCap(ROUND);
  ellipseMode(CENTER);
  strokeWeight(tb);
  noStroke();
  
  // setup video capture
  if (webcam) {
    video = new Capture(this, w, h, 15); // start camera
    video.start();
    // video = new Capture(this, w, h, camera, fps);
  }

  // setup font
  PFont font = findFont(fonts);
  textFont(font);
  textSize(ts);
  
  // reset frame number counters to zero
  // saveBytes("data/frames.dat", new byte[] { 0x00, 0x00, 0x00, 0x00 });
  
  // load frame number
  byte sb[] = loadBytes("data/frames.dat"); 
  sn = (int) (sb[0] & 0xff) * 256 + (int) (sb[1] & 0xff); // get frame number
  ot = (int) (sb[2] & 0xff) * 256 + (int) (sb[3] & 0xff); // get offline frames total
  rf = ot;
  
  // save gray background for image fade later
  background(FADE);
  banner = get(0, 0, w, tb); 
}

/**
 * load a font from a list of preferences
 */
PFont findFont(String[] fc) {
  // load font for text
  String[] il = PFont.list();
  for (int i = 0; i < fc.length; i++) {
    for (int j = 0; j < il.length; j++) {
      if (il[j].equals(fc[i])) {
        return createFont(fc[i], ts, true);
      }
    }
  }
  return createFont(fc[0], ts, true); // give up?
}

/**
 * draw each frame of video and detect edges
 */
void draw() {
  if (!pp) { // not paused
    if (!off && webcam && video.available()) {
      video.read(); // get webcam data
      video.loadPixels(); // load webcam pixels
      src = video;
    } else if (off && ot > 0) {
      // offline usage with saved png frames
      PImage file = loadImage("data/offline/" + nf(of, 4) + ".png");
      src.copy(file, 0, 0, file.width, file.height, 0, 0, w, h);
      of = (of + 1) % ot;
    }
  }
      
  image(src, 0, 0, w, h); // show video
      
  if (rec) { // save frames for offline use
    saveFrame("data/offline/" + nf(rf++, 4) + ".png");  
    saveData();
  }
  
  if (v || (off && ot == 0)) { // if not in video mode
    background(YELLOW); // fill yellow background
  }
  
  if (gs) filter(GRAY); // grayscale
  
  // count of dots set to zero
  dc = 0; bc = 0; kc = 0; ec = 0; 
  ex = new int[bn]; ey = new int[bn]; // reset extra dots
  bx = new int[bn]; by = new int[bn]; // reset bright dots
  kx = new int[bn]; ky = new int[bn]; // reset dark dots
  
  // loop from top to bottom then left to right
  for (int y = 0; y < h - s; y += (int) (s * q)) {
    n = 0; a = new int[as]; // reset average buffer pointer
    for (int x = 0; x < w - s; x += (int) (s * q)) {
      calc(x, y, true); // check for edge
    }
  }
    
  // loop from left to right then top to bottom
  for (int x = 0; x < w - s; x += (int) (s * q)) {
    n = 0; a = new int[as]; // reset average buffer pointer
    for (int y = 0; y < h - s; y += (int) (s * q)) {
      calc(x, y, false); // check for edge
    }
  }
    
  // draw marker ellipses
  if (mk) {
    mark(bc, bx, by, RED); // mark brightest area
    mark(kc, kx, ky, GREEN); // mark darkest area
  }
    
  // render lines
  if (rl) { // try to draw edges
    if (ca) {
      // all colours together
      if (bc + kc + ec > 0) {
        int all = ec + kc + bc, alx[] = new int[all], aly[] = new int[all];
        for (int i = 0; i < ec; i++) { alx[i] = ex[i]; aly[i] = ey[i]; }
        for (int i = 0; i < bc; i++) { alx[i + ec] = bx[i]; aly[i + ec] = by[i]; }
        for (int i = 0; i < kc; i++) { alx[i + ec + bc] = kx[i]; aly[i + ec + bc] = ky[i]; }
        edge(all, alx, aly, blendColor(FADE, MAGENTA, HARD_LIGHT));
      }
    } else {
      // three separate brightness levels as distinct colours
      if (ec > 0) edge(ec, ex, ey, blendColor(FADE, BLUE, HARD_LIGHT));
      if (kc > 0) edge(kc, kx, ky, blendColor(FADE, GREEN, HARD_LIGHT));
      if (bc > 0) edge(bc, bx, by, blendColor(FADE, RED, HARD_LIGHT));
    }
  }
  
  // print overlay info
  if (si == 0) info(dc, bc, sn);
  base();
  
  // show help text
  if (sh) {
    help();
    if (++hc > hd) sh = false; 
  }
  
  // save file if key pressed
  if (sf) {
    sn++;
    saveData();
    save("save/vegetables-" + nf(sn, 5) + ".png");
    sf = false;
  }
}

void saveData() {
    byte[] sb = {
      (byte) (sn / 256), (byte) (sn % 256),
      (byte) (rf / 256), (byte) (rf % 256),
    };
    saveBytes("data/frames.dat", sb);
}

/**
 * calculate average brightness and place in a circular buffer to check
 * the differences between successive squares of pixels. if this exceeds
 * a pre-determined threshold, mark the dot, indicating if we found it
 * in a left-to-right or top-to-bottom scan. also saves the locations
 * of bright and dark points to allow marking these areas later.
 */
public void calc(int x, int y, boolean ltr) {
  a[n % as] = 0; // reset average
  
  // loop through a square of pixels and average brightness
  for (int xx = x; xx < x + s; xx++) {
    for (int yy = y; yy < y + s; yy++) {
      int p = src.pixels[(yy * w) + xx]; // get pixel value
      a[n % as] += contrast(brightness(p)) / (s * s); // update average
    }
  }
  
  // get all differences between this and previous
  int[] ad = diff(a, n);
  int ds = sign(ad); // sign of all differences
  
  // if the differences are all over the threshold in same direction
  if ((n > as) && (ds != 0) && sum(ad) > (as * dt)) {
    dc++; // increment count of dots
    
    boolean bd = sum(a) > (as * bt); // bright?
    if (bd) { // save
      bx[bc] = x; by[bc] = y; bc++;
    }
    boolean kd = sum(a) < (as * kt); // dark?
    if (kd) { // save
      kx[kc] = x; ky[kc] = y; kc++;
    }
    if (!bd && !kd) { // everything else
      ex[ec] = x;  ey[ec] = y; ec++;
    }
    
    // set fill colour based on various properties of the dot we found
    if (rd) {
      fill(ltr ? color(bd ? 10 : 50, 10, kd ? 10 : 50) : color(bd ? 10 : 50, 50, kd ? 10 : 50));
      ellipse(v ? w - x : x, y, s / m, s / m); // draw the dot on screen
    }
  }
  
  ++n; // move circular average buffer pointer on for comparision next time
}

public float contrast(float bright) {
  float contrast = (ce * (bright - 128.0)) + 128.0;
  if (bright > 0.1) if (--cp > 0) println(bright + " -> " + contrast);
  if (contrast < 0.0)
    return 0.0f;
  else if (contrast > 256.0)
    return 256.0;
  else
    return contrast;
}

/**
 * mark a circle round the extent of an array of saved points
 */
public void mark(int n, int[] x, int[] y, color c) { 
  /* draw circle round black points */
  if (n > 0) { // if any found
    int ax = 9999, ay = 9999, zx = 0, zy = 0, i = 0;
    
    // find min and max x and y
    for (; i < n; i++) { 
      ax = min(ax, x[i]);
      ay = min(ay, y[i]);
      zx = max(zx, x[i]);
      zy = max(zy, y[i]);
    }
    
    // calculate x y and width of circle
    int azx = abs(ax - zx);
    int azy = abs(ay - zy);
    int ex = ax + (azx / 2);
    int ey = ay + (azy / 2);
  
    // draw circle
    stroke(c);
    fill(blendColor(FADE, c, HARD_LIGHT), 30);
    ellipse(v ? w - ex  : ex, ey, max(azx, azy) / m, max(azx, azy) / m);
    noFill();
    noStroke();
  }
}

/**
 * display system information
 */
public void info(int dc, int bc, int sn) {
  // dim screen behind text at top
  int t = ts + ts + ts + tb + tb;
  blend(banner, 0, 0, w, tb, 0, 0, w, t, HARD_LIGHT);
  
  // program name and date bold text in black
  fill(BLACK);
  textAlign(LEFT, TOP);
  bold(program.toUpperCase() + " " + version + " - " + desc.toUpperCase(), tb, 0);
  textAlign(RIGHT, TOP);
  String dd = year() + "-" + nf(month(), 2) + "-" + nf(day(), 2);
  bold(dd, w - tb, 0);
  
  // info is dim text
  fill(DIM);
  textAlign(LEFT, TOP);
  text("points " + ec + "/" + bc + "/" + kc, tb, ts + tb);
  String mode = (rl ? (cl ? "c" : "l") : "-") + (rl && cx ? "x" : "-") + (rl && ca ? "a" : "-") + (rd ? "d" : "-");
  text("params " + dt + ";" + bt + ";" + ss + ";" + ds + ";" + s + ";" + nf(ce, 2, 1) + ";" + mode, tb, ts + ts + tb);
  textAlign(RIGHT, TOP);
  text(w + "x" + h + " at " + nf(frameRate, 2, 2) + " fps", w - tb, ts + tb);
  text("frame # " + nf(off ? of : rec ? rf : sn, 4), w - tb, ts + ts + tb);
}

/**
 * display copyright and status
 */
public void base() {
  int sw = (int) textWidth("xxxxxxxxxxxxx");
  
  // dim screen behind text at bottom
  blend(banner, 0, 0, w, tb, si == 2 ? w - (sw + tb + tb) : 0, h - (ts + tb), w, (ts + tb), HARD_LIGHT);
  
  if (si != 2) {
    // copyright
    fill(BLACK);
    textAlign(LEFT, BASELINE);
    text("copyright 2009-2017 by andrew donald kennedy", tb, h - tb);
  }
  
  // offline/recording/paused status
  textAlign(RIGHT, BASELINE);
  String wt = pp ? "PAUSED" : off ? "REPLAY" : rec ? "RECORD" : "WEBCAM";
  if (si != 0) {
    fill(DIM);
    text("# " + nf(off ? of : rec ? rf : sn, 4) + "       ", w - tb, h - tb);
  }
  fill(pp ? GREEN : off ? BLUE : rec ? RED : DIM);
  bold(wt, w - tb, h - tb);
}

/**
 * draw centered box, for help text
 */
int[] tbox(int bw, int bh) {
  // dim screen behind text box
  int bx = (w / 2) - (bw / 2) - (2 * tb);
  int by = (h / 2) - (bh / 2) - (2 * tb);
  blend(banner, 0, 0, w, tb, bx, by, bw + (4 * tb), bh + (4 * tb), HARD_LIGHT);
  
  // draw border round box
  noFill();
  stroke(BLACK);
  strokeWeight(tb / 2.0);
  rect(bx, by, bw + (4 * tb), bh + (4 * tb));
  noStroke();
  strokeWeight(tb);
  
  // return top left of box
  return new int[] { bx, by };
}

/**
 * display help text
 */
public void help() {
  fill(BLACK);
  int hw = 0; // max width of text
  for (int l = 0; l < help.length; l++) {
    hw = max((int) textWidth(help[l]), hw);
  }
  
  // draw text box
  int[] hb = tbox(hw, help.length * ts);
  
  // display help text
  textAlign(LEFT, TOP);
  bold(help[0], hb[0] + (2 * tb), hb[1] + tb);
  text(help[1], hb[0] + (2 * tb), hb[1] + (2 * tb) + ts);
    
  // draw each line and bold first word
  for (int l = 2; l < help.length; l++) {
    // gray out nonsensical options 
    boolean dim = (help[l].indexOf(" - ") != -1)
        &&  ((help[l].indexOf("space") == 0 && rec)
          || (help[l].charAt(0) == 'r' && (!webcam || pp || off))
          || (help[l].charAt(0) == 'c' && !rl)
          || (help[l].charAt(0) == 'x' && !rl)
          || (help[l].charAt(0) == 'a' && !rl)
          || (help[l].charAt(0) == 'o' && (pp || !webcam || rec || ot == 0)));
    fill(dim ? DIM : BLACK);
    text(help[l], hb[0] + (2 * tb), hb[1] + tb + tb + (ts * l));
    if (help[l].indexOf(" - ") != -1) { // key option description
      text(split(help[l], ' ')[0], 1 + hb[0] + (2 * tb), hb[1] + tb + tb + (ts * l));
    }
  }
}

/**
 * calculate differences between element and previous in circular average buffer
 */
public int[] diff(int[] a, int n) {
  int[] d = new int[as];
  for (int i = 0; i < as; i++) {
    d[i] = a[((as + n) - i) % as] - a[((as + n) - (i + 1)) % as];
  }
  return d;
}

/**
 * check sign of all elements of an array, return +/- 1 like java compareTo
 */
public int sign(int[] d) {
  int p = 0, n = 0;
  for (int i = 0; i < as; i++) {
    if (d[i] >= 0) p++;
    if (d[i] <= 0) n--;
  }
  if (p >= as / 2) return 1;
  if (n >= as / 2) return -1;
  return 0;
}

/**
 * add absolute values of an array
 */
public int sum(int[] d) {
  int st = 0;
  for (int i = 0; i < as; i++) {
    st += abs(d[i]);
  }
  return st;
}

/**
 * cheap bold text trick
 */
public void bold(String msg, int x, int y) {
  text(msg, x, y);
  text(msg, x, y + 1);
}

/**
 * save frame on space key, toggle various states on others,
 * quit and so on. will not allow nonsensical combinations,
 * such as going offline when paused, changing lines to curves if
 * lines are not being rendered and such like.
 */
void keyReleased() {
  if (key != CODED) {
    if (key == ' ') {
      if (!rec) pp = !pp; // cannot pause if recording
    }
    if (key == ENTER || key == RETURN) sf = true;
    if (key == 'q' || key == 'Q') {
      if (webcam) video.stop();
      exit();
    }
    if (key == 'i' || key == 'I') si = (si + 1) % 3;
    if (key == 'm' || key == 'M') mk = !mk;
    if (key == 'v' || key == 'V') v = !v;
    if (key == 'd' || key == 'D') rd = !rd;
    if (key == 'l' || key == 'L') rl = !rl;
    if (key == 'g' || key == 'G') gs = !gs;
    if (rl) { // only if rendering lines
      if (key == 'a' || key == 'A') ca = !ca;
      if (key == 'c' || key == 'C') cl = !cl;
      if (key == 'x' || key == 'X') cx = !cx;
    }
    if (key == 'r' || key == 'R') {
      if (!pp && !off && webcam) { // only if not paused or offline
        rec = !rec;
        if (rec) {
          rf = 0;
        } else {
          ot = rf;
        }
      }
    }
    if (key == 'h' || key == 'H' || key == '?') {
      sh = true; hc = 0; // reset counter for display time
    }
    if (key == 'o' || key == 'O') {
      if (!pp && !rec && webcam) { // only if not paused or already recording
        off = !off;
      }
    }
  }
}

/**
 * change various parameters up and down using number keypresses.
 * pairs of numbers from left to right change up and down by a
 * specific delta for each parameter. minimum and maximum values
 * are limited and cross-linked to other relevant parameters too.
 */
void keyPressed() {
  int dd = 0, db = 0, dss = 0, dds = 0, dsk = 0;
  float dce = 0;
  
  // change delta based on keypress
  if (key == '1') dd  = -1;
  if (key == '2') dd  = +1;
  if (key == '3') db  = -5;
  if (key == '4') db  = +5;
  if (key == '5') dss = -5;
  if (key == '6') dss = +5;
  if (key == '7') dds = -5;
  if (key == '8') dds = +5;
  if (key == '9') dsk = -1;
  if (key == '0') dsk = +1;
  if (key == '[') dce = -0.2;
  if (key == ']') dce = +0.2;
  if (key == '=') setParams(mp[++ps % 2]);

  // update paramaters
  dt = min(100, max(0, dt + dd));
  bt = min(255, max(dt, bt + db));
  ss = min(ds, max(0, ss + dss));
  ds = min(500, max(ss, ds + dds));
  s = min(10, max(2, s + dsk));
  ce = min(10, max(1, ce + dce));
}

void edge(int np, int[] x, int[] y, color c) {
  boolean[] u = new boolean[np]; u[0] = true; // checked points
  int fx = x[0], fy = y[0]; // first point
  int lx = fx, ly = fy; // last point drawn
  
  // start drawing
  begin(lx, ly, c);
  
  // draw lines based on closeness of dots
  while (true) {
    int rv[] = closest(lx, ly, x, y, u, np, c);
    if (rv[0] == -1) break; // no more dots
    if (rv[0] == 0) continue; // no line drawn
    
    lx = x[rv[0]]; // save last point
    ly = y[rv[0]];
    
    // if at the end of a shape
    if (rv[1] == 1) {
      // closed shape if last point near first
      int sd = ((fx - lx) * (fx - lx)) + ((fy - ly) * (fy - ly));
      if (cx && sd < (ds * ds * 4)) { // closed?
        fill(blendColor(FADE, c, HARD_LIGHT), 80);
        endShape(CLOSE);
      } else endShape();
      
      // start next shape
      begin(lx, ly, c);
      fx = lx; fy = ly;
    }
  }
  
  // done drawing edges
  endShape();
  noStroke();
}

void begin(int x, int y, color c) { 
  fill(c);
  noStroke();
  ellipse(v ? w - x : x, y, tb, tb);
  noFill();
  stroke(c);
  beginShape();
  
  // initial point
  if (cl) curveVertex(v ? w - x : x, y);
  else vertex(v ? w - x : x, y);
}

/**
 * return array of two integers indicating closest point found.
 * first is point number if closest inside shape radius
 * zero indicates closest was inside cluster radius
 * negative one indicates no more points.
 * second point is one for end of shape, otherwise zero.
 */
int[] closest(int ax, int ay, int[] x, int[] y, boolean[] u, int np, color c) {
  int cx = 0, cy = 0;
  int cn = -1;
  int cd = 99999;
  
  // look at all the points and check distance (squared)
  for (int i = 0; i < np; i++) {
    if (!u[i]) {
      int id = ((ax - x[i]) * (ax - x[i])) + ((ay - y[i]) * (ay - y[i]));
      if (id < cd) {
        cd = id;
        cn = i;
        cx = x[i];
        cy = y[i];
      }
    }
  }
  
  // if we found a closest point
  if (cn != -1) {
    u[cn] = true;
    if (cd > (ds * ds)) { // outside 'different' radius
      return new int[] { cn, 1 };
    } else if (cd > (ss * ss)) {  // outside 'same' radius
      if (cl) curveVertex(v ? w - cx : cx, cy);
      else vertex(v ? w - cx : cx, cy);
      return new int[] { cn, 0 };
    } else {  // inside 'same' radius
      return new int[] { 0, 0 };
    }
  }
  
  // TODO new algorithm, remove zig-zag lines
  // point > diff - new shape as before
  // diff > point > same - find center of all points < same this turn and plot
  // same > point - record point against this turn
  
  return new int[] { -1, 0 };
}
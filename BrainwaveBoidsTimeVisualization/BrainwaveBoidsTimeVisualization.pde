import oscP5.*;
import netP5.*;
import oscP5.OscMessage;

OscP5 oscP5;

// Muse absolute band powers (TP9, AF7, AF8, TP10)
float[] alpha = new float[4];
float[] beta  = new float[4];
float[] gamma = new float[4];
float[] theta = new float[4];
float[] delta = new float[4];

float valence = 0;
float arousal = 0;

// short & mid windows
float valenceS=0, arousalS=0; // reactive
float valenceM=0, arousalM=0; // stable
final float aS = 0.50;  // short EMA
final float aM = 0.12;  // mid EMA

// Boid system
ArrayList<Boid> boids;
PVector target;
int N_INIT = 300;

// Emotion-driven flock weights and perception radius
float ALIGN=1.0, COHESION=1.0, SEPERATION=1.5;
float NEIGHBOR = 70;

float impulseTimer = 0;
float lastRatio = 0;

PGraphics trail;

// UI
boolean showHUD = true;

void setup() {
  size(800, 800, P2D);
  frameRate(60);
  oscP5 = new OscP5(this, 8000);

  boids = new ArrayList<Boid>();
  for (int i = 0; i < N_INIT; i++) {
    boids.add(new Boid(random(width), random(height)));
  }

  target = new PVector(width/2, height/2);
  background(0);

  trail = createGraphics(width, height, P2D);
  trail.beginDraw();
  trail.background(0);
  trail.endDraw();

  for (int i=0;i<4;i++){ alpha[i]=beta[i]=gamma[i]=theta[i]=delta[i]=0.001; }
}

void draw() {
  noStroke();
  fill(0, 0, 0, 35);
  rect(0, 0, width, height);

  // 1) Update emotions & weights
  updateEmotionState();
  maybeTriggerSpike();
  applyEmotionToWeights();

  // 2) long trails
  trail.beginDraw();
  trail.noStroke();
  trail.fill(0, 0, 0, 8); // 18 → 8
  trail.rect(0, 0, width, height);
  trail.endDraw();

  // 3) Boids
  for (Boid b : boids) {
    b.seek(target);
    b.flock(boids);
    eventImpulse(b);
    b.update();

    // trail dot
    trail.beginDraw();
    trail.noStroke();
    int col = b.getColor();
    trail.fill(red(col), green(col), blue(col), 120);
    trail.ellipse(b.position.x, b.position.y, 2.2, 2.2);
    trail.endDraw();

    b.show();
  }

  float cam = sin(millis()*0.0007)*0.6;
   pushMatrix();
  translate(width/2, height/2);
  //scale(1.5); 
  translate(-width/2, -height/2);
   translate(cam, -cam);
   image(trail, 0, 0);
   popMatrix();
  // 5) HUD
  if (showHUD){
    fill(255);
    textSize(13);
    text("Valence: " + nf(valence, 1, 3), 10, 18);
    text("Arousal: " + nf(arousal, 1, 3), 10, 36);
    text("Valence Mid/Short  : " + nf(valenceM, 1, 3) + " / " + nf(valenceS, 1, 3), 10, 54);
    text("Arousal Mid/Short  : " + nf(arousalM, 1, 3) + " / " + nf(arousalS, 1, 3), 10, 72);
    text("Align/Coh/Sep: " + nf(ALIGN,1,2) + " / " + nf(COHESION,1,2) + " / " + nf(SEPERATION,1,2), 10, 90);
    text("Neighbor R   : " + int(NEIGHBOR), 10, 108);
  }
}

// ========================== Affect Computing and Events ==========================

void updateEmotionState() {
  float alphaAvg = average(alpha);
  float betaAvg = average(beta);
  float thetaAvg = average(theta);
  
  arousal = betaAvg/(alphaAvg+thetaAvg);
  valence = alpha[2] - alpha[1];

  arousal = constrain(arousal, -2, 2);
  valence = constrain(valence, -2, 2);

  // double EMA
  valenceS = lerp(valenceS, valence, aS);
  arousalS = lerp(arousalS, arousal, aS);
  valenceM = lerp(valenceM, valence, aM);
  arousalM = lerp(arousalM, arousal, aM);
}

void maybeTriggerSpike() {
  float alphaAvg = max(0.0001, average(alpha));
  float ratio = average(beta) / alphaAvg;
  if (ratio - lastRatio > 0.18) {
    impulseTimer = 1.0;
  }
  lastRatio = lerp(lastRatio, ratio, 0.5);
}

void applyEmotionToWeights() {
  ALIGN = map(arousalM, -1, 1, 0, 2.0);
  SEPERATION   = map(arousalM, -1, 1, 1.6, 1.05);
  COHESION   = map(valenceM, -1, 1, 0.7, 1.9);
  NEIGHBOR = map(arousalM, -1, 1, 55, 150);
}

void eventImpulse(Boid b) {
  if (impulseTimer > 0) {
    PVector n = b.velocity.copy();
    if (n.magSq() < 0.0001) n = PVector.random2D();
    n.rotate(HALF_PI).setMag(1.0 * impulseTimer);
    b.applyForce(n);
    impulseTimer -= 0.06;
    impulseTimer = max(0, impulseTimer);
  }
}

// ============================ Boid Class ==============================

class Boid {
  PVector position;
  PVector velocity;
  PVector acceleration;
  float maxForce = 0.2;
  float maxSpeed = 2.5;

  Boid(float x, float y) {
    position = new PVector(x, y);
    velocity = PVector.random2D();
    acceleration = new PVector();
  }

  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void seek(PVector target) {
    
    float attraction = map(arousalS, -1, 1, 0.2, 0.9);
    PVector desired = PVector.sub(target, position);
    desired.setMag(maxSpeed * 0.6 * attraction);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxForce * 0.6 * attraction);

    PVector wind = globalFlow(position.x, position.y);
    wind.mult(1.1);

    applyForce(steer.add(wind));
  }

  void flock(ArrayList<Boid> boids) {
    PVector alignment = align(boids, NEIGHBOR);
    PVector cohesion  = cohere(boids, NEIGHBOR * 1.15);
    PVector separation= separate(boids, NEIGHBOR * 0.55);

    alignment.mult(ALIGN);
    cohesion.mult(COHESION);
    separation.mult(SEPERATION);

    applyForce(alignment);
    applyForce(cohesion);
    applyForce(separation);
  }

  void update() {
    maxSpeed = map(arousalM, -1, 1, 1.8, 7.0);
    maxForce = map(arousalS, -1, 1, 0.16, 0.38); 

    position.add(velocity);
    velocity.add(acceleration);
    velocity.limit(maxSpeed);
    acceleration.mult(0);
    edges();
  }

  void show() {
    float lifeFactor = map(valenceM, -1, 1, 0.8, 1.35);
    float vibrate    = sin(frameCount * max(0.2, 0.5 * (arousalS+1))) * 1.6;
    float s = max(2.5, 6.2 * lifeFactor + vibrate);

    int c = getColor();
    float speedRatio = constrain(velocity.mag()/maxSpeed, 0, 1);
    c = lerpColor(color(30,30,40), c, 0.65 + 0.35*speedRatio);

    noStroke();
    fill(c, 220);
    ellipse(position.x, position.y, s, s);
  }

  int getColor() {
    return circumplexColor(valenceM, arousalM);
  }

  void edges() {
    if (position.x > width) position.x = 0;
    if (position.x < 0) position.x = width;
    if (position.y > height) position.y = 0;
    if (position.y < 0) position.y = height;
  }

  PVector align(ArrayList<Boid> boids, float perception) {
    PVector steering = new PVector();
    int total = 0;
    for (Boid other : boids) {
      if (other == this) continue;
      float d = PVector.dist(position, other.position);
      if (d < perception) {
        steering.add(other.velocity);
        total++;
      }
    }
    if (total > 0) {
      steering.div((float) total);
      steering.setMag(maxSpeed);
      steering.sub(velocity);
      steering.limit(maxForce);
    }
    return steering;
  }

  PVector cohere(ArrayList<Boid> boids, float perception) {
    PVector steering = new PVector();
    int total = 0;
    for (Boid other : boids) {
      if (other == this) continue;
      float d = PVector.dist(position, other.position);
      if (d < perception) {
        steering.add(other.position);
        total++;
      }
    }
    if (total > 0) {
      steering.div((float) total);
      steering.sub(position);
      steering.setMag(maxSpeed);
      steering.sub(velocity);
      steering.limit(maxForce);
      steering.mult(1.05);
    }
    return steering;
  }

  PVector separate(ArrayList<Boid> boids, float perception) {
    PVector steering = new PVector();
    int total = 0;
    for (Boid other : boids) {
      if (other == this) continue;
      float d = PVector.dist(position, other.position);
      if (d < perception && d > 0.0001) {
        PVector diff = PVector.sub(position, other.position);
        diff.div(d*d); // inverse-square
        steering.add(diff);
        total++;
      }
    }
    if (total > 0) {
      steering.div((float) total);
      steering.setMag(maxSpeed);
      steering.sub(velocity);
      steering.limit(maxForce);
    }
    return steering;
  }
}

// ========================= Flow & Color =======================

// Curl Noise
PVector globalFlow(float x, float y) {
  float s = 0.003;
  float t = millis() * 0.00025;   
  float eps = 0.0005;          

  float nx = x * s + 100.0 + valenceM*0.6;
  float ny = y * s + 200.0 - valenceM*0.6;

  float a = noise(nx, ny + eps, t);
  float b = noise(nx, ny - eps, t);
  float c = noise(nx + eps, ny, t);
  float d = noise(nx - eps, ny, t);

  float curlX = a - b;  
  float curlY = d - c;  
  PVector f = new PVector(curlX, curlY);

  if (f.magSq() < 1e-6) f = PVector.random2D().mult(0.01);
  f.normalize();
  float mag = map(arousalM, -1, 1, 0.6, 1.6);
  f.mult(mag);
  f.rotate(0.3 * arousalS); 
  return f;
}

float average(float[] arr) {
  float sum = 0;
  for (int i=0; i<arr.length; i++) sum += arr[i];
  return sum / max(1, arr.length);
}

// Russell circumplex color: hue=valence, lightness=arousal
int circumplexColor(float v, float a) { // v,a ∈ [-1,1]
  float H = map(v, -1, 1, 0.0, 1.0);
  float S = map(abs(v), 0, 1, 0.42, 0.95);
  float L = map(a, -1, 1, 0.35, 0.75);
  return hsl(H, S, L);
}

int hsl(float h, float s, float l){
  float q = l < 0.5 ? l*(1+s) : l + s - l*s;
  float p = 2*l - q;
  float r = hue2rgb(p,q,h + 1.0/3.0);
  float g = hue2rgb(p,q,h);
  float b = hue2rgb(p,q,h - 1.0/3.0);
  return color(
    255*constrain(r,0,1),
    255*constrain(g,0,1),
    255*constrain(b,0,1)
  );
}

float hue2rgb(float p,float q,float t){
  if(t<0) t+=1;
  if(t>1) t-=1;
  if(t<1.0/6.0) return p + (q-p)*6*t;
  if(t<1.0/2.0) return q;
  if(t<2.0/3.0) return p + (q-p)*(2.0/3.0 - t)*6;
  return p;
}

// ============================== OSC ===================================

void oscEvent(OscMessage msg) {
  String addr = msg.addrPattern();

  if (addr.equals("/muse/elements/alpha_absolute")) {
    for (int i = 0; i < 4 && i < msg.typetag().length(); i++) alpha[i] = msg.get(i).floatValue();
  } else if (addr.equals("/muse/elements/beta_absolute")) {
    for (int i = 0; i < 4 && i < msg.typetag().length(); i++) beta[i] = msg.get(i).floatValue();
  } else if (addr.equals("/muse/elements/gamma_absolute")) {
    for (int i = 0; i < 4 && i < msg.typetag().length(); i++) gamma[i] = msg.get(i).floatValue();
  } else if (addr.equals("/muse/elements/theta_absolute")) {
    for (int i = 0; i < 4 && i < msg.typetag().length(); i++) theta[i] = msg.get(i).floatValue();
  } else if (addr.equals("/muse/elements/delta_absolute")) {
    for (int i = 0; i < 4 && i < msg.typetag().length(); i++) delta[i] = msg.get(i).floatValue();
  }
}

// ============================ Controls ================================

void keyPressed(){
  if (key == 'h' || key == 'H') showHUD = !showHUD;
}

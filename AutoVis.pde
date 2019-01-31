import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.concurrent.TimeUnit;
import processing.opengl.*;
import processing.sound.AudioIn;
import processing.sound.Sound;

Minim minim;
AudioPlayer groove;
AudioRenderer render;
PImage img;

void setup()
{
  //set up background image 
  size(1920, 1080, OPENGL);
  img = loadImage("sunset.jpg");

  //load downloaded song
  minim = new Minim(this);
  groove = minim.loadFile("war.mp3", 1024);
  groove.loop();  

  frameRate(30);

  //setup render
  render = new Visualize(groove);
  groove.addListener(render);
  render.setup();
}

void draw()
{
  render.draw();
  image(img, 0, 0);
}


void stop()
{
  groove.close();
  minim.stop();
  super.stop();
}

//setup function for audio processing
abstract class AudioRenderer implements AudioListener {
  float[] left;
  float[] right;
  synchronized void samples(float[] samp) { 
    left = samp;
  }
  synchronized void samples(float[] sampL, float[] sampR) { 
    left = sampL; 
    right = sampR;
  }
  abstract void setup();
  abstract void draw();
}


//function to process audio
abstract class FourierRenderer extends AudioRenderer {
  FFT fft; 
  float maxFFT;
  float[] leftFFT;
  float[] rightFFT;

  //setup fast fourier transform
  FourierRenderer(AudioSource source) {
    float gain = .125;
    fft = new FFT(source.bufferSize(), source.sampleRate());
    maxFFT =  source.sampleRate() / source.bufferSize() * gain;
    fft.window(FFT.HAMMING);
  }

  //split into frequency ranges 
  void calc(int bands) {
    if (left != null) {
      leftFFT = new float[bands];
      fft.linAverages(bands);
      fft.forward(left);
      for (int i = 0; i < bands; i++) leftFFT[i] = fft.getAvg(i);
    }
  }
}


class Visualize extends FourierRenderer {
  BeatDetect beat;
  int n = 48; //constant to input into fft
  float squeeze = .3; //sensitivity
  int beatDelta = 0; //change color based on beat detection
  float val[];

  Visualize(AudioSource source) {
    super(source); 
    val = new float[n];
  }


  void setup() {
    colorMode(RGB, n, n, n); //valid rgb values in range from 0 to n
    rectMode(CORNERS);
    noStroke();
    noSmooth();  

    beat = new BeatDetect();
  }

  synchronized void draw() {

    if (left != null) {  

      float dx = width / n - 20;
      float dy = height / n * .2;
      super.calc(n);

      //draw boxes representing frequency ranges
      for (int i=0; i < n - 20; i++)
      {
        val[i] = lerp(val[i], pow(leftFFT[i] * (i+1), squeeze), .04); //last number is how fast bars move
        float x = map(i* -1, 0, n, height, 0);
        float y = map(val[i], 0, maxFFT, 0, width/4);

        pushMatrix();
        translate(x - 850, -(dx + y)/2 + 864);
        fill(250, i * 1.1, 0);
        box(dy + 5, dx + y, 1);
        fill(255, 255, 255);  
        popMatrix();
      }

      //changes background color when beat is onset
      beat.detect(groove.mix);
      ambientLight(20, 20, 20); //add brightness
      if ( beat.isOnset() == true) beatDelta = 30;
      ambientLight(20 + beatDelta, 20 + beatDelta/6, 20 + beatDelta/6); //color of light
      beatDelta *= 0.98; //how fast color fades
    }
  }
}

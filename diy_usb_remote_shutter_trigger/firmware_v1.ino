int green = 2;
int gray = 3;
int led = 13;
int serialData = 48;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication at 9600 bits per second:
  Serial.begin(9600);
  
  pinMode(green, OUTPUT);
  pinMode(gray, OUTPUT);
  pinMode(led, OUTPUT);  
  digitalWrite(green, LOW);
  digitalWrite(gray, LOW);
  digitalWrite(led, LOW);
}

// the loop routine runs over and over again forever:
void loop() {
  if (Serial.available() > 0) {
    serialData = Serial.read();
    //Serial.println(serialData);
  }
  
  if (serialData == 49) {
    digitalWrite(green, HIGH);
    digitalWrite(gray, HIGH);
    digitalWrite(led, HIGH);
  }
  
  if (serialData == 48) {
    digitalWrite(green, LOW);
    digitalWrite(gray, LOW);
    digitalWrite(led, LOW);
  }
  
  delay(1);        // delay in between reads for stability
}


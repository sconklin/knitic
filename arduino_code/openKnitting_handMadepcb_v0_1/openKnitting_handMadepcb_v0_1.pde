/*
 *
 * OPEN KNITTING
 * @Description: Code for open source machine
 * @Authors: Mar Canet & Varvara Guljajeva 
 * @Versions:0.1v 
 *
 */

#define arduinoTypeMEGA "mega"
//#define arduinoTypeUNO uno

//---------------------------------------------------------------------------------
// Controled by Toshiva
class solenoids{
private:
  int dataSector1;
  int dataSector2;
  int dataArray[8];
  int dataArraypos[8];
  byte myDataOut;
#ifdef arduinoTypeMEGA
  int amegaPinsArray[16];
#endif
  unsigned long lastArrayWrite;
  //Pin connected to ST_CP of 74HC595
  int latchPin;
  //Pin connected to SH_CP of 74HC595
  int clockPin;
  //Pin connected to DS of 74HC595
  int dataPin;
  //--- Important: All Pins must be 8 or higher (in PORTB range)
  int latchPinPORTB;
  int clockPinPORTB;
  int dataPinPORTB;
public:
#ifdef arduinoTypeMEGA
  boolean solenoidstateChanged[16];
#endif
  boolean changedsolenoids;
  boolean solenoidstate[16];
  String _16solenoids;
  solenoids(){
    changedsolenoids = true;
#ifdef arduinoTypeMEGA
    //int amegaPinsArrayTemp[16] = {22,24,26,28,30,32,34,36,21,23,25,27,29,31,33,35};
    int amegaPinsArrayTemp[16] = {21,23,25,27,29,31,33,35,22,24,26,28,30,32,34,36};
    for(int i=0; i<16; i++){
      amegaPinsArray[i] = amegaPinsArrayTemp[i];
      pinMode(amegaPinsArrayTemp[i], OUTPUT);
    }
#endif
  }

  ~solenoids(){
  }

  void setup(){
    //Pin connected to ST_CP of ULN2803A
    latchPin = 8;
    //Pin connected to SH_CP of 74HC595
    clockPin = 12;
    //Pin connected to DS of 74HC595
    dataPin = 11;

    //set pins to output because they are addressed in the main loop
    pinMode(latchPin, OUTPUT);
    pinMode(clockPin, OUTPUT);
    pinMode(dataPin, OUTPUT);

    _16solenoids = "1010101010101010";

    // Holds the actual order in which the bits have to be shifted in
    dataArraypos[0] = 0x07;
    dataArraypos[1] = 0x06;
    dataArraypos[2] = 0x05;
    dataArraypos[3] = 0x04;
    dataArraypos[4] = 0x03;
    dataArraypos[5] = 0x02;
    dataArraypos[6] = 0x01;
    dataArraypos[7] = 0x00;

    //Arduino doesn't seem to have a way to write binary straight into the code 
    //so these values are in HEX.  Decimal would have been fine, too. 
    dataArray[0] = 0x80; //10000000
    dataArray[1] = 0x40; //01000000
    dataArray[2] = 0x20; //00100000
    dataArray[3] = 0x10; //00010000
    dataArray[4] = 0x08; //00001000
    dataArray[5] = 0x04; //00000100
    dataArray[6] = 0x02; //00000010
    dataArray[7] = 0x01; //00000001

    for(int i=0;i<16;i++){
      solenoidstate[i] = (_16solenoids[i] != '0');
    }

    lastArrayWrite = millis();
    changedsolenoids=true;
    //setupSPI();
  }

  void loop(){
    if(/*(millis()-lastArrayWrite > 1000) || */ changedsolenoids==true /*&& (millis()-lastArrayWrite > 150)*/ ){
      changedsolenoids = false;
#ifdef arduinoTypeMEGA
      setArduinoMegaPins();
#endif

#ifdef arduinoTypeUNO
      dataSector1 = 0x00;
      dataSector2 = 0x00;
      for (int j = 0; j < 8; ++j) {
        //load the light sequence you want from array
        if(solenoidstate[j]==true){
          dataSector1 = dataSector1 ^ dataArray[dataArraypos[j]];
        }
        if(solenoidstate[j+8]==true){
          dataSector2 = dataSector2 ^ dataArray[dataArraypos[j]];
        }  
      }
      sendValuesToShifOut(dataSector1, dataSector2);//classic ShiftOut
      //iProcess(dataSector1, dataSector2);// fast ShiftOut
#endif
      lastArrayWrite = millis();
    }
  }

#ifdef arduinoTypeMEGA
  void setArduinoMegaPins(){
    for(int i=0;i<16;i++){
      if(solenoidstateChanged[i]==true){
        if(solenoidstate[i]==true){
          digitalWrite(amegaPinsArray[i], HIGH);
        }
        else{
          digitalWrite(amegaPinsArray[i], LOW);
        }
      }
    }
  }
#endif

#ifdef arduinoTypeUNO
  // fast shiftOut ----------------------------------------------------------
  void setupSPI(){
    //--- Using standard shiftOut:
    // at 2 Shift Registers - 225 fails, 275 works ..
    //--- Using shiftOutFast:
    // at 2 Shift Register - 50 fails, 75 works
    latchPinPORTB = latchPin - 8;
    clockPinPORTB = clockPin - 8;
    dataPinPORTB = dataPin - 8;

    digitalWrite(latchPin,LOW);
    digitalWrite(dataPin,LOW);
    digitalWrite(clockPin,LOW);
    byte clr;
    SPCR |= ( (1<<SPE) | (1<<MSTR) ); // enable SPI as master
    //SPCR |= ( (1<<SPR1) | (1<<SPR0) ); // set prescaler bits
    SPCR &= ~( (1<<SPR1) | (1<<SPR0) ); // clear prescaler bits
    clr=SPSR; // clear SPI status reg
    clr=SPDR; // clear SPI data reg
    SPSR |= (1<<SPI2X); // set prescaler bits
    //SPSR &= ~(1<<SPI2X); // clear prescaler bits
    delay(10); 
  }

  void iProcess(byte data1, byte data2){
    //--- This code can run using a 20 timer delay! :)
    latchOff();     
    //spi_transfer(data2); 
    //spi_transfer(data1); 
    shiftOutFast(dataPin,clockPin,data2); 
    shiftOutFast(dataPin,clockPin,data1);    
    latchOn();
  }
  
  //--- shiftOutFast - Shiftout method done in a faster way .. needed for tighter timer process
void shiftOutFast(int myDataPin, int myClockPin, byte myDataOut) {
  //=== This function shifts 8 bits out MSB first much faster than the normal shiftOut function by writing directly to the memory address for port
  //--- clear data pin
  dataOff();

  //Send each bit of the myDataOut byte MSBFIRST
  for (int i=7; i>=0; i--)  {
    clockOff();
    //--- Turn data on or off based on value of bit
    if ( bitRead(myDataOut,i) == 1) {
      dataOn();
    }
    else {      
      dataOff();
    }
    //register shifts bits on upstroke of clock pin  
    clockOn();
    //zero the data pin after shift to prevent bleed through
    dataOff();
  }
  //stop shifting
  digitalWrite(myClockPin, 0);
}

  void dataOff(){
    bitClear(PORTB,dataPinPORTB);
  }

  void clockOff(){
    bitClear(PORTB,clockPinPORTB);
  }

  void clockOn(){
    bitSet(PORTB,clockPinPORTB);
  }

  void dataOn(){
    bitSet(PORTB,dataPinPORTB);
  }

  void latchOn(){
    bitSet(PORTB,latchPinPORTB);
  }

  void latchOff(){
    bitClear(PORTB,latchPinPORTB);
  }
/*
  byte spi_transfer(byte data)
  {
    SPDR = data;            // Start the transmission
    loop_until_bit_is_set(SPSR, SPIF); 
    return SPDR;                    // return the received byte, we don't need that
  }
*/
  // classic shiftOut -----------------------------------------------------
  void sendValuesToShifOut(byte data1, byte data2){

    // clear registers
    digitalWrite(latchPin, 0);
    setShiftOut(dataPin, clockPin, 0x00);   
    setShiftOut(dataPin, clockPin, 0x00);
    digitalWrite(latchPin, 1);

    //ground latchPin and hold low for as long as you are transmitting
    digitalWrite(latchPin, 0);
    //move 'em out
    setShiftOut(dataPin, clockPin, data2);   
    setShiftOut(dataPin, clockPin, data1);
    //return the latch pin high to signal chip that it 
    //no longer needs to listen for information
    digitalWrite(latchPin, 1);
  }

  void setShiftOut(int myDataPin, int myClockPin, byte myDataOut){
    // This shifts 8 bits out MSB first, 
    //on the rising edge of the clock,
    //clock idles low

    //internal function setup
    int i=0;
    int pinState;
    //pinMode(myClockPin, OUTPUT);
    //pinMode(myDataPin, OUTPUT);

    //clear everything out just in case to
    //prepare shift register for bit shifting
    digitalWrite(myDataPin, 0);
    digitalWrite(myClockPin, 0);

    //for each bit in the byte myDataOut
    //NOTICE THAT WE ARE COUNTING DOWN in our for loop
    //This means that %00000001 or "1" will go through such
    //that it will be pin Q0 that lights. 
    for (i=7; i>=0; i--)  {
      digitalWrite(myClockPin, 0);

      //if the value passed to myDataOut and a bitmask result 
      // true then... so if we are at i=6 and our value is
      // %11010100 it would the code compares it to %01000000 
      // and proceeds to set pinState to 1.
      if ( myDataOut & (1<<i) ) {
        pinState= 1;
      }
      else {	
        pinState= 0;
      }

      //Sets the pin to HIGH or LOW depending on pinState
      digitalWrite(myDataPin, pinState);

      //register shifts bits on upstroke of clock pin  
      digitalWrite(myClockPin, 1);
    }

    //stop shifting
    digitalWrite(myClockPin, 0);
  }

#endif
};
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
class encoders{
private:
  // digital pins
  int encoder0PinA;
  int encoder0PinB;
  int encoder0PinC;
  int encoder0PinALast;
  int encoder0PinBLast;
  int encoder0PinCLast;
  String directionEncoders;
  String lastDirectionEncoders;
  int headDirectionAverage;
public:
  String _8segmentEncoder;   
  String last8segmentEncoder;
  int segmentPosition;
  int encoder0Pos;
  int lastEncoder0Pos;
  int headDirection;
  encoders(){
    #ifdef arduinoTypeUNO
    encoder0PinA = 2;
    encoder0PinB = 3;
    encoder0PinC = 4;
    #endif
     #ifdef arduinoTypeMEGA
    encoder0PinA = 2;
    encoder0PinB = 3;
    encoder0PinC = 4;
    #endif
    headDirection = 0;
    encoder0Pos = -1000;
    lastEncoder0Pos = -1;
    segmentPosition = -1;
    _8segmentEncoder = "";
    last8segmentEncoder = "";
    lastDirectionEncoders = "";
    headDirectionAverage = 0;
  }

  ~encoders(){
  }

  void setup(){
    pinMode(encoder0PinA,INPUT);
    pinMode(encoder0PinB,INPUT);
    pinMode(encoder0PinC,INPUT);
  }

  void loop(){
    directionEncoders = "";
    if(digitalRead(encoder0PinA)== HIGH){ 
      directionEncoders += "ON"; 
    }
    else{ 
      directionEncoders += "OFF"; 
    }
    directionEncoders += "-";
    if(digitalRead(encoder0PinB)== HIGH){ 
      directionEncoders += "ON"; 
    }
    else{ 
      directionEncoders += "OFF"; 
    }
    last8segmentEncoder = _8segmentEncoder;
    _8segmentEncoder = "";
    if(digitalRead(encoder0PinC)== HIGH){ 
      _8segmentEncoder += "ON"; 
    }
    else{ 
      _8segmentEncoder += "OFF"; 
    }
    //directionEncoders +=_8segmentEncoder;
    // head direction
    if(lastDirectionEncoders!=directionEncoders){
      if( 
      (lastDirectionEncoders=="OFF-OFF" && directionEncoders=="OFF-OFF") || 
        (lastDirectionEncoders=="OFF-OFF" && directionEncoders=="ON-OFF") || 
        (lastDirectionEncoders=="ON-OFF" && directionEncoders=="ON-ON") || 
        (lastDirectionEncoders=="ON-ON" && directionEncoders=="OFF-ON") || 
        (lastDirectionEncoders=="OFF-ON" && directionEncoders=="OFF-OFF") 
        ){
        headDirectionAverage +=1;
        //Serial.println(directionEncoders+"-Left");
        if((encoder0Pos != -1000) && (encoder0Pos/4 > -31)){
          encoder0Pos--;
        }
      }
      else if( 
      (lastDirectionEncoders=="OFF-ON" && directionEncoders=="ON-ON") || 
        (lastDirectionEncoders=="ON-ON" && directionEncoders=="ON-ON") || 
        (lastDirectionEncoders=="ON-ON" && directionEncoders=="ON-OFF") || 
        (lastDirectionEncoders=="ON-OFF" && directionEncoders=="OFF-OFF") || 
        (lastDirectionEncoders=="OFF-OFF" && directionEncoders=="OFF-ON") 
        ){
        headDirectionAverage -=1;
        //Serial.println(directionEncoders+"-Right");
        if((encoder0Pos != -1000) && (encoder0Pos/4 < 231)){
          encoder0Pos++;
        }
      }
    }

    // know when head changer from one 8 knidles segment 
    if(_8segmentEncoder!=last8segmentEncoder ){ 
      //
      if(headDirectionAverage>2){
        headDirection =+1;
        //Serial.println("d:+1");
      }
      else if(headDirectionAverage<-2){
        headDirection =-1;
        //Serial.println("d:-1");
      }
      else{
        headDirection = headDirection*-1;
        //Serial.println("change direction"+String(headDirection));
      }
      headDirectionAverage = 0;
      segmentPosition +=headDirection;
      //encoder0Pos = segmentPosition*8;
      /*
       Serial.print(",s,");
       Serial.print(headDirection);
       Serial.print(",");
       Serial.print(segmentPosition);
       Serial.println(",e,");
       */
    }
    lastDirectionEncoders = directionEncoders;

  }
};
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
class soundAlerts{
private:
  // analog pin
  int piezoPin;
public:
  soundAlerts(){
  }
  ~soundAlerts(){
  }

  void setup(){
    piezoPin = 3;
  }

  void startMachine(){
    int delayms = 50;
    for(int i=0;i<3;i++){
      analogWrite(piezoPin, 20);      // Almost any value can be used except 0 and 255
      // experiment to get the best tone
      delay(delayms);          // wait for a delayms ms
      analogWrite(piezoPin, 0);       // 0 turns it off
      delay(delayms);          // wait for a delayms ms 
    }
  }

  void endPattern(){
    int delayms = 50;
    for(int i=0;i<5;i++){
      analogWrite(piezoPin, 20);      // Almost any value can be used except 0 and 255
      // experiment to get the best tone
      delay(delayms);          // wait for a delayms ms
      analogWrite(piezoPin, 0);       // 0 turns it off
      delay(delayms);          // wait for a delayms ms 
    }
  }
};
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
class endLines{
private:
  soundAlerts* mySoundAlerts;
  // analog arduino pin
  int endLineLeftAPin;
  int endLineRightAPin;
  int * encoderPos; 
  int filterValueLeft;
  int filterValueRight;
  int lastLeft;
  int lastRight;
public:
  boolean started;
  int * segmentPosition;
  int row;
  endLines(){
  }
  ~endLines(){
  }

  void setup(){
    endLineLeftAPin = 0;
    endLineRightAPin = 1;
    filterValueLeft = 730;
    filterValueRight = 730;
    row = 0;
    started = false;
  }

  void setPosition(int * _encoderPos, int * _segmentPosition, soundAlerts* _mySoundAlerts){
    encoderPos = _encoderPos;
    segmentPosition = _segmentPosition;
    mySoundAlerts = _mySoundAlerts;
  }

  void loop(){
    //if(analogRead(endLineLeftAPin)>600) Serial.println(analogRead(endLineLeftAPin));
    if( analogRead(endLineLeftAPin) > filterValueLeft   ){
      if(!lastLeft){
        *encoderPos = 200*4;
        *segmentPosition = 25;
        //Serial.print("inside left:");
        //Serial.print("change encoder0Pos:");
        //Serial.println(*encoderPos);
        started = true;
      }
      lastLeft = true;
    }
    else{
      lastLeft = false;
    }

    //if(analogRead(endLineRightAPin)>600) Serial.println(analogRead(endLineRightAPin));
    if( analogRead(endLineRightAPin) > filterValueRight ){
      if(!lastRight){
        *encoderPos = 0;
        *segmentPosition = 1;
        //Serial.print("inside right:");
        //Serial.print("change encoder0Pos:");
        //Serial.println(*encoderPos);
        started = true;
      }
      lastRight = true;
    }
    else{
      lastRight = false;
    }
  }

};
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
class communication{
private:
  encoders* myEncoders;
  endLines* myEndlines;
  solenoids* mysolenoids;
  char buf[48];
  unsigned long lastSendTimeStamp;
  int readCnt;
public:
  String _status;
  communication(){
  }
  ~communication(){
  }

  void setup(encoders* _myEncoders, endLines* _myEndlines, solenoids* _mysolenoids){
    myEncoders = _myEncoders;
    myEndlines = _myEndlines;
    mysolenoids = _mysolenoids;
    lastSendTimeStamp = millis();
    readCnt = 0;
  }

  // send data to OF

  void sendSerialToComputer(){
    if((myEncoders->last8segmentEncoder!=myEncoders->_8segmentEncoder) || (myEncoders->lastEncoder0Pos!=myEncoders->encoder0Pos) || (millis()-lastSendTimeStamp)>200 ){
      lastSendTimeStamp = millis();
      Serial.print(",s,");
      Serial.print(myEncoders->segmentPosition);
      Serial.print(",");
      Serial.print(myEncoders->encoder0Pos/4);
      Serial.print(",");
      if(myEndlines->started){ 
        Serial.print('1');
      }
      else{ 
        Serial.print('0'); 
      }
      Serial.print(",");
      Serial.print(myEncoders->headDirection);
      Serial.print(",");
      Serial.print(_status);
      Serial.println(",e,");

      //
      myEncoders->lastEncoder0Pos = myEncoders->encoder0Pos;
    }
  }

  // get data from OF
  void receiveSerialFromComputer(){
    GetString(buf, sizeof(buf));

    int start = -1;
    int _end  = -1;

    // look for start inside string received
    for(int i=0;i<sizeof(buf);i++){
      if(buf[i]=='s'){
        start =i;
        break;
      }
    }

    // look for end inside string received
    for(int i=sizeof(buf)-1;i>0;i--){
      if(buf[i]=='e'){
        _end =i;
        break;
      }
    }

    if(start!=-1 && _end!=-1 )
    {
      int id = 0;
      char * pch;
      pch = strtok (buf," ,.-");
      while (pch != NULL)
      {
        // get start
        if(id == 0){
          if(*pch=='s') 
            id+=1;        
        }
        // get solenoids
        else if(id==1){
          boolean changedsolenoids = false;
          for(int i=0; i<16;i++){
#ifdef arduinoTypeMEGA
            mysolenoids->solenoidstateChanged[i] = false;
#endif
            if( pch[i]=='0' ){
              if(mysolenoids->solenoidstate[i] != false){ 
                changedsolenoids = true;
#ifdef arduinoTypeMEGA
                mysolenoids->solenoidstateChanged[i] = true;
#endif
              }
              mysolenoids->solenoidstate[i] = false;
            }
            else{
              if(mysolenoids->solenoidstate[i] != true){ 
                changedsolenoids = true;
#ifdef arduinoTypeMEGA
                mysolenoids->solenoidstateChanged[i] = true;
#endif
              }
              mysolenoids->solenoidstate[i] = true;
            }
          }
          //set new values if there is new values
          if(changedsolenoids){
            mysolenoids->changedsolenoids = true;
          }
          id +=1;
        }
        // get status
        else if(id==2 ){
          _status = pch[0];
          //reset_initialpos
          if(_status == 'r'){
            myEndlines->started = false;
          }
          id += 1;
          //break; // exit from while
        }
        pch = strtok(NULL, " ,.-");
      }

      // clear buffer
      for (int i=0; (i<sizeof(buf))&&(id==3); ++i){
        buf[i] = 'X';
      }
    }
  }

  void GetString(char *buf, int bufsize)
  {
    // while there's stuff to read and we haven't seen an end
    while(Serial.available() && (readCnt >= 0)){
      char rc = Serial.read();
      // waiting for start signal
      if((readCnt == 0) && (rc == 's')){
        buf[readCnt] = 's';
        readCnt++;
      }
      // have seen start signal
      else if(readCnt>0){
        buf[readCnt] = rc;
        readCnt++;
        if(rc == 'e'){
          // signal to break while loop
          readCnt = -readCnt;
          break;
        }
        else if(readCnt >= (bufsize-1)){
          readCnt = 0;
        }
      }
    }

    // check for end conditions
    if(readCnt < 0){
      /*
      Serial.print("##");
       for (int i=0; i<abs(readCnt); ++i){
       Serial.print(buf[i]);
       Serial.flush();
       }
       Serial.println("##");
       Serial.flush();
       */
      readCnt = 0;
    }
  }
};
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
// class declaration
encoders myEncoders;
endLines myEndlines;
solenoids mysolenoids;
soundAlerts mySoundAlerts;
communication myCommunicator;

void setup()
{ 
  Serial.begin(115200);
  mySoundAlerts.setup();
  mysolenoids.setup();
  myEncoders.setup();
  myEndlines.setup();
  myEndlines.setPosition(&myEncoders.encoder0Pos, &myEncoders.segmentPosition, &mySoundAlerts);
  myCommunicator.setup(&myEncoders,&myEndlines,&mysolenoids);
  myCommunicator._status = "o";
} 

void loop() {
  // receive solenoids from computer
  myCommunicator.receiveSerialFromComputer();
  mysolenoids.loop();
  // get data from sensors and send to computer
  myEncoders.loop();
  myEndlines.loop();
  myCommunicator.sendSerialToComputer();
} 




















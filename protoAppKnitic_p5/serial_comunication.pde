void setupSerialConnection() {
  try {
    println("try to connect");
    println(Serial.list()[0]);
    // Open the port you are using at the rate you want:
    myPort = new Serial(this, Serial.list()[0], 115200);
    lastConnection = millis();
  }
  catch(Exception e) {
  }
}

void autoConnectAndReceiveSerial() {
  try {
    // knowing if is connected
    if (abs(millis()-lastMessageReceivedFromSerial)>2000) {
      if (abs(lastConnection-millis())>1500) {
        usbConected = false;
        if ( myPort != null) {
          myPort.clear();
          myPort.stop();
        }
        myPort = null;
        setupSerialConnection();
      }
    }
    else {
      usbConected = true;
    }

    receiveSerial();
  }
  catch(Exception e) {
  }
}

void sendSerial16() {
  try {
    if ( (millis()-lastMessageSendFromSerial)>500  || !last16Solenoids.equals(_16Solenoids) ) {
      String _16SolenoidsNew = _16Solenoids.replace('9', '1');
      if (headDownSelenoid || isPatternFinishKnitting() ) {
        _16SolenoidsNew ="00000000000000";
      }
      String message = ",s,"+_16SolenoidsNew+","+status+",e,";
      println(_16SolenoidsNew);
      myPort.write(message);
      String filler = "";
      for (int i = message.length(); i<46; i++) {
        filler += "e";
      }
      myPort.write(filler);
      lastMessageSendFromSerial = millis();
    }
    last16Solenoids = _16Solenoids;
  }
  catch(Exception e) {
    println("Error in send serial");
  }
}

void receiveSerial() {
  try {
    int timeStart = millis();
    serialAvailableBuffer = myPort.available();
    while (myPort!=null && myPort.available ()>0  && (millis()-timeStart<300) ) {
      //println("Receive Serial___"+Integer.toString(myPort.available()));
      String all = "";
      // read from buffer, but only if there's no end-of-message to be processed
      boolean findMessage = false;
      while ( (myPort.available ()>0) ) { //&& !((lastSerialData+all).contains("e") && (lastSerialData+all).contains("s") ) ) {
        all += myPort.readChar();
        if (findOneMessage(all) ) {
          break;
        }
      }
    }
  }
  catch(Exception e) {
    println("ERROR in receive serial "+e.getMessage());
  }
}

boolean findOneMessage(String all) {
  String[] values = split(lastSerialData+all, ',');
  int _start =-1;
  int _end =-1;
  for (int i=(values.length-1);i>0;i--) {
    if (values[i].equals("e")) {
      _end =i;
      break;
    }
  }

  // look for end inside string received
  if (_end!=-1) {
    // look for start inside string received
    for (int i=(values.length-1);i>0;i--) {
      if (values[i].equals("s")) {
        _start =i;
        break;
      }
    }
  }

  if ( _start!=-1 && _end!=-1  && _end > _start+5 && (_end-_start)==6 ) {
    println("Receive Serial_WITH ALL MESSAGE:");
    counterMessagesReceive+=1;
    lastMessageReceivedFromSerial = millis();
    println(_start);
    println(_end);
    stitch = Integer.valueOf(values[_start+2]);
    print(","+Integer.toString(stitch));
    section = int(stitch/8);
    print(","+Integer.toString(section));
    endLineStarted = !values[_start+3].equals("0");

    if (endLineStarted) { 
      print(",true");
    }
    else {
      print(",false");
    }

    headDirection = -Integer.valueOf(values[_start+4]);
    print(","+Integer.toString(headDirection));

    try {
      statusMachine = values[_start+5];
    }
    catch(Exception e) {
      println("ERROR status "+e.getMessage());
      print("total values:");
      println(values.length);
    }

    println(",end of getting values");

    lastSerialData = "";
    // get part message to other
    if (_end+1<values.length) {
      for (int i=_end+1;i<values.length;i++) {
        lastSerialData +=","+values[i];
      }
    }
    // calculate with new data
    brain();
    //println("call brain");
    return true;
  }
  else {
    lastSerialData +=all;
    return false;
  }
}


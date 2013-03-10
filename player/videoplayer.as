// New timer design
// Emergency stop by press keyup
// improved GUI
// Solved duplicate NetStream event problem
package {
		import flash.display.Sprite;
		import flash.net.NetConnection;
		import flash.net.NetStream; 
		import flash.net.NetStreamInfo 
		import flash.net.Socket;
		import flash.media.Video;
		import flash.text.*;
		import flash.events.*;
		import flash.utils.Timer;
		import flash.system.Security;
    
    public class videoplayer extends Sprite {
        	
    	    private function currentTime():Number{
    	    		var timeNow:Date = new Date();
    	    		return timeNow.time;   	    		
    			}
    			
    			private var nc:NetConnection;
					private var ns:NetStream;
					private var client:Object;
					
					public function videoplayer () {
						
						function printDebug(debug_message:String):void{
							debug_tf.appendText("["+currentTime()+"]"+debug_message);
						}
						
						// exp_controller configurations
						var ip:String = "router";
						//var ip:String = "192.168.34.139";
						var port:int 	= 9001;
						var fastTest:Boolean = true;		// allows fast test
						
						// declare varibles
						// quality
						var init_buf_time:int 		= 0;
						var total_rebuf_time:int	=	0;	
						var mean_rebuf_time:int		= 0;
						var rebuf_count:int				= 0;
						// controlling
						var state:int							= 0;
						var timeMS:uint						= 0;
						var pbuf:int							= 0;
						var lastEvent:String;
						var runningFlag:Boolean 	= false;
						//others
						var rx_buf:String;
						var vdo_url:String;		
						//Regexp
						var extract_cmd:RegExp = /^(.+):(.*)$/;
						var cmd_result:Array;
						//test
						var startTIME:Number;
						var stopTIME:Number;
						var vid:Video
						
						
						function videoScreen(w:int,h:int):void{
							// Add video to stage
							vid = new Video(w,h);
							addChild (vid);
							vid.x = 0;
							vid.y = 0; 
						}
						
						videoScreen(320,240);
 
						
						// Add Text Field - Display Quality of Delivery 
						var tf:TextField = new TextField();
						addChild(tf);
						tf.width 				= 320;
						tf.x 						= 0;
						tf.y 						= 240;
						
						// Add Text Field - Display debugging information
						var debug_tf:TextField = new TextField();
						addChild(debug_tf);
						debug_tf.width 			= 320;
						debug_tf.height 		= 50;
						debug_tf.x 					= 0;
						debug_tf.y 					= 320;
						debug_tf.border 		= true;
						debug_tf.multiline 	= true;
		
						// Initialize socket
						var s:Socket = new Socket();
						
						// Listen to socket events
						s.addEventListener(Event.CONNECT, onConnect);
						s.addEventListener(Event.CLOSE, onClose);
						s.addEventListener(IOErrorEvent.IO_ERROR, onError);
						s.addEventListener(ProgressEvent.SOCKET_DATA, onResponse);
						s.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecError);
						
						// Timer of 100/1000 second for updating display
						var t:Timer = new Timer(100);
						t.addEventListener(TimerEvent.TIMER, updateVDQ);
						t.start();
						
						// Timer of 1 second for reconnecting with exp_controller
						var recon_timer:Timer = new Timer(1000);
						recon_timer.addEventListener(TimerEvent.TIMER, reconnect);
												
						// Connect to exp_controller
						recon_timer.start();
						//s.connect(ip, port);
						stage.addEventListener(KeyboardEvent.KEY_UP, keyHandler);

						// startEXP
						function start_exp():void {
						debug_tf.text = "";	//Clear text field
						
						// Initialize net stream
						nc = new NetConnection();
						nc.connect (null);
						ns = new NetStream(nc);
	          // Add callback method for listening on NetStream meta data
	          client = new Object();
	          ns.client = client;
	          // Listen to Netstream event
	          ns.addEventListener(NetStatusEvent.NET_STATUS, statusHandler);
	          // Attache to video stage
	          vid.attachNetStream ( ns );
							
						// Initial variables
						state 						= 1;
						init_buf_time 		= 0;
						total_rebuf_time 	= 0;
						mean_rebuf_time		= 0;
						rebuf_count				= 0;
						timeMS 						= 0;
						//runningFlag				= false;
						runningFlag				= true;
	      
	          ns.bufferTime 		= pbuf;			// Set video player buffer size
	          startTIME 				= currentTime();
	          debug_tf.appendText("["+startTIME+"] Start play\n");
						ns.play(vdo_url);							// Set video path and play
						}
						
	          // Handler Netsream events
						function statusHandler(event:NetStatusEvent):void{
							switch(state){
								case 1: //The initial buffering state (State:1)
								{
									switch( event.info.code ){ 
										case "NetStream.Play.Start":
											// Do nothing
											break;
										case "NetStream.Buffer.Full":	// stop initial buffering state
											stopTIME 			= currentTime();
											init_buf_time = stopTIME - startTIME;							//get initial buffering time
											state 				= 2;
											lastEvent 		= "Full";
											debug_tf.appendText("["+stopTIME+"] Finish initial buffering\n");
											break;     
		                default: 
		                	printDebug("Error: unexpected Netstream event (State "+state+")\n");
		                	printDebug("Error:"+event.info.code+"\n");
		                	abortTest();   
									}
								}
								break; 
								case 2: //The re-buffering state (State:2)
								{
									switch( event.info.code ){ 
										case "NetStream.Buffer.Empty": 	//buffer under threshold state
											if(lastEvent == "Full"){				//Check duplicate event
												startTIME = currentTime();					//start timer
												rebuf_count++;									//count re-buffering event
												debug_tf.appendText("["+startTIME+"] Start re-buffering of "+rebuf_count+"\n");
												lastEvent = "Empty";						//record the current event
											}else{
												printDebug("Warning! ignore duplicate Empty (State "+state+")\n");
											}		
											break;
										case "NetStream.Buffer.Full": 	//buffer over threshold state
											if(lastEvent == "Full"){				//Check duplicate event
												printDebug("Warning! ignore duplicate Full (State "+state+")\n");
											}else{
												stopTIME 			= currentTime();	// stop timer
												debug_tf.appendText("["+stopTIME+"] Finish re-buffering of "+rebuf_count+"\n");
												timeMS				= timeMS + stopTIME - startTIME;
												lastEvent 		= "Full";					//record the current event
											}
											break;
										case "NetStream.Buffer.Flush": 	//No-more buffering state
											if(lastEvent == "Empty"){
													printDebug("Warning! Empty -> Flush (State "+state+")\n");
													stopTIME 			= currentTime();
													debug_tf.appendText("["+stopTIME+"] re-buffering of "+rebuf_count+"\n");
													timeMS				= timeMS + stopTIME - startTIME;
											}
											state=3;																						// move to playing state															
											break; 										     
		                default: 
		                	printDebug("Error: unexpected Netstream event (State "+state+")\n");
		                	printDebug("Error:"+event.info.code+"\n");  
		                	abortTest();
									}
								}
								break;
								case 3: //The non-buffering state (State: 3)
								{
										switch( event.info.code ){ 
											case "NetStream.Play.Stop": 		// video stop playing
												// Do nothing here
											case "NetStream.Buffer.Empty": 	// buffer is completely depleted
												sendResult();
			                default: 
			                	printDebug("Error: unexpected Netstream event (State "+state+")\n");
			                	printDebug("Error:"+event.info.code+"\n");
			                	abortTest(); 
										}
									break;
								}
								default: 
			          	printDebug("Error: unexpected state number (State "+state+")\n");
			          	abortTest(); 
		          } 
						}
						
						// send result back to controller
						function sendResult():void {
							if(runningFlag == true){
								runningFlag = false;
								ns.dispose();
								printDebug("Send result "+init_buf_time+" - "+rebuf_count+" - "+mean_rebuf_time+"\n");
								s.writeUTFBytes(init_buf_time+"-"+rebuf_count+"-"+mean_rebuf_time+"\n");
								s.flush();
							}
						}
						
						// abort test
						function abortTest():void{
							if(runningFlag == true){
								runningFlag = false;
								ns.dispose();
								printDebug("Abort test\n");
								s.writeUTFBytes("play:ERR, abort test\n");
								s.flush();
							}
						}
						
						// Events
						// Keyboard event
						function keyHandler(event:KeyboardEvent):void {
							abortTest();
						}
												
						// Socket event - On connect
						function onConnect(e:Event):void {
							if(recon_timer.running == true){
								recon_timer.stop();
								recon_timer.reset();
							}
							printDebug("Connected to exp_Controller\n");
						}
						// Socket event - On disconnect
						function onClose(e:Event):void {
							printDebug("Warning: reconnecting to exp_controller ...\n");
							recon_timer.start();
						}
						// Socket event - On error
						function onError(e:IOErrorEvent):void {
							printDebug("Error: socket is error\n");
							//printDebug("Error: socket is error\n");
						}
						// Socket event - On security error
						function onSecError(e:SecurityErrorEvent):void {
							printDebug("Error: socket is security error\n");
						}

						// Timer event - update GUI every 100ms
						function updateVDQ(event:TimerEvent):void{
							tf.text = "";	//Clear text field

							if(state==1){
								tf.appendText("Initial buffering time:\t\t"+ timeMS + " ms.\n");
							}else{
								tf.appendText("Initial buffering time:\t\t"+ init_buf_time + " ms.\n");
							}
							if(state==2){
								tf.appendText("Re-buffering count:\t\t"+ rebuf_count + " times\t["+timeMS+" ms]\n");
								tf.appendText("Mean Re-buffering time:\t"+ mean_rebuf_time +" ms.\n");
							}else{
								tf.appendText("Re-buffering count:\t\t"+ rebuf_count + " times\n");
								tf.appendText("Mean Re-buffering time:\t"+ mean_rebuf_time +" ms.\n");
							}
							if(ns){
								if(fastTest == true){
									if(runningFlag == true){
										tf.appendText(ns.bytesLoaded+"\t/"+ns.bytesTotal+"\n");		// Display progress bar
										if(ns.bytesLoaded == ns.bytesTotal){											// check video download complete
											total_rebuf_time = timeMS;																//read total re-buffering time
											mean_rebuf_time = total_rebuf_time/rebuf_count;						//calculate mean re-buffering time
											printDebug("The whole video file is loaded\n");
											sendResult();
									}
								}
							}
						}
						}
						
						// Timer event - reconnect every 1 second;
						function reconnect(event:TimerEvent):void{
							s.connect(ip, port);
						}
						
						// Socket event - On receive data
						function onResponse(e:ProgressEvent):void {
							if (s.bytesAvailable>0) {
								rx_buf = s.readUTFBytes(s.bytesAvailable);
								//Debug
								printDebug("rx_buf: "+rx_buf+"\n");
								cmd_result = extract_cmd.exec(rx_buf);	// Extract command
								switch(cmd_result[1]){ 
									case "play": 
										start_exp();
										break;
									case "setRES": 
										switch(cmd_result[2]){
											case "internet":
												vdo_url = "http://www.mediacollege.com/video-gallery/testclips/20051210-w50s.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;
											case "test480p":
												vdo_url = "http://192.168.34.139/sintel_480p_30fps.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;	
											case "300":
												vdo_url = "http://server10/video_300.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;	
											case "480p":
												vdo_url = "http://server10/sintel_480p_30fps.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;	
											case "720p":
												vdo_url = "http://server10/sintel_720p_30fps.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;	
											case "1080p":
												vdo_url = "http://server10/sintel_1080p_30fps.flv";
												s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
												s.flush();
												break;	
											default: 
    										printDebug("Error: wrong resolution\n");
    										vdo_url = "";
    										s.writeUTFBytes("ERR:"+cmd_result[1]+", undefined resolution\n");
												s.flush();
    								}
										break;
									case "setPBUF": 
										if(parseInt(cmd_result[2])>=0){
											pbuf = parseInt(cmd_result[2]);
											printDebug("Set player buffer: "+parseInt(cmd_result[2])+" seconds\n");
											s.writeUTFBytes(cmd_result[1]+":"+cmd_result[2]);
											s.flush();
										}else{
											s.writeUTFBytes("ERR:"+cmd_result[1]+", invalid buffer size\n");
											s.flush();
										}
										break;
			                default: 
			                	s.writeUTFBytes("ERR:unknow command\n");
			                	s.writeUTFBytes("fail\n");
												s.flush();
								}
							}
						}// socket event
    			}
		}
}
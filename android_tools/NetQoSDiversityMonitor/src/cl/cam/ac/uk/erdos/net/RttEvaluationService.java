package cl.cam.ac.uk.erdos.net;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.util.Calendar;
import java.util.Date;
import java.util.Iterator;
import java.util.Properties;




import cl.cam.ac.uk.crowdGps.R;


import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.location.GpsSatellite;
import android.location.GpsStatus;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Bundle;
import android.os.Environment;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.SystemClock;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import android.telephony.gsm.GsmCellLocation;
import android.util.Log;
import android.widget.Toast;


public class RttEvaluationService extends Service implements Runnable{
	
	private static RttEvaluatorActivity MAIN_ACTIVITY;
	private static final String TAG = "RTT_NET";
	//Standard timeout for sntpclient in gps
//	private static final int timeout = 60000;
	private static final String host = "www.google.co.uk";

    private static final int NTP_PORT = 123;

    // Number of seconds between Jan 1, 1900 and Jan 1, 1970
    // 70 years plus 17 leap days
    private static final long OFFSET_1900_TO_1970 = ((365L * 70L) + 17L) * 24L * 60L * 60L;

    // round trip time in milliseconds
    private long mRoundTripTime;
	
	//Managers
	private static PowerManager.WakeLock wl = null;
	private static PowerManager pm = null;
	private static TelephonyManager tm = null;
	private static LocationManager lm = null;

	private static String filenamePing = "output_rtt.txt";
	private static String filenameTraffic = "output_traffic.txt";
	private static String filenameLoc = "output_loc.txt";
	
	private SignalStateListener snrlistener = null;
	
	//Num repetitions
	//private static int NUM_REPETITIONS = 10000;//1h for long tests. 300 for short ones
	//private static long SAMPLING_PERIOD = 1000; //IN Milliseconds
	private static long startTime = 0;
	//private static int MAXGPSFIX=60*60; //Should be like 1h
	
	private static final Class[] mStartForegroundSignature = new Class[]{int.class, Notification.class};
	private static final Class[] mStopForegroundSignature = new Class[]{boolean.class};
	
	private NotificationManager mNM;
	private Method mStartForeground;
	private Method mStopForeground;
	
	private GpsLocHandler gpsLocListener;
	
	private Object [] mStartForegroundArgs = new Object[2];
	private Object [] mStopForegroundArgs = new Object [1];
	
	private static final long sleepTime = 60000;

	private static long prevRxMnet0 = 0;
	private static long prevTxMnet0 = 0;
	private static TxRxThread thTraffic = null;
	
	public static void setMainActivity(RttEvaluatorActivity activity){
		Log.e(TAG, "Activity added. Task ID: "+activity.getTaskId());
		MAIN_ACTIVITY=activity;
	}

	@Override
	public IBinder onBind(Intent intent) {
		// TODO Auto-generated method stub
		return null;		
	}
	
	
	@Override
	public void onStart(Intent intent, int startId){
			Log.i(TAG, "ONSTART");
			CharSequence text = "Press to restart";
			CharSequence prevText = "PowerMonitorSyc!";
			
			Notification notification = new Notification(R.drawable.icon, "Notify", System.currentTimeMillis());
			PendingIntent contentIntent = PendingIntent.getActivity(this, 0, new Intent(this, RttEvaluatorActivity.class), 0);
			notification.setLatestEventInfo(this, prevText, text, contentIntent);
			startForeground(R.string.foreground_service_started, notification);			
			Log.e(TAG, "Foreground service started");	

			lm = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
			
	        //Add listener
	      	lm.addGpsStatusListener(gpsListener);		
	      	//Location Listeners
	      	gpsLocListener = new GpsLocHandler();
	      	lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0, 0, gpsLocListener);
	      	
			try{
				Thread th = new Thread (this);
				th.start();		
				thTraffic = new TxRxThread();
				thTraffic.start();
			}
			catch(Exception e){
				Log.e(TAG, "Couldn't start thread");
			}
	}

	@Override
	public void onDestroy () {
		// TODO Auto-generated method stub
		Log.e(TAG, "OnDestroy()");		
		super.onDestroy();
	}
	
	@Override
	public void onCreate(){
		Log.e(TAG, "Service.onCreate()");
		pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
		Log.e(TAG, "Power Manager created");
		//Get Full wakelock to keep screen at full brightness (to make sure we can collect cell ID)
		wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "WAKELOCK");
		wl.acquire();
		tm = (TelephonyManager) getSystemService(Context.TELEPHONY_SERVICE);
		snrlistener = new SignalStateListener(0);		
		Log.e(TAG, "Creating notification");
		mNM = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
		try{
			mStartForeground = getClass().getMethod("startForeground", mStartForegroundSignature);
			mStopForeground = getClass().getMethod("stopForeground", mStopForegroundSignature);			
		}
		catch(Exception e){
			Log.e(TAG, "Error: "+e.getMessage());			
			mStartForeground = mStopForeground = null;
		}
		Log.e(TAG, "OnCreate finished");
	}

	public void run() {
		// TODO Auto-generated method stub
		int counter = 0;
		while (true){
				performRttRequest();
				try{
		         	Thread.sleep(sleepTime);
		         	counter++;
				}
				catch(Exception e){
					System.out.println("Error: "+e.getMessage());
				}
		}		
	}

	public void performRttRequest(){
        try {
			String s = null;
			String pingOutput = "-1,-1,-1,-1";
	        Process p = Runtime.getRuntime().exec("ping -i 1 -c 5 www.google.es");
	            
	        BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));
	        BufferedReader stdError = new BufferedReader(new InputStreamReader(p.getErrorStream()));

	        // read the output from the command
	        //System.out.println("Here is the standard output of the command:\n");
	        while ((s = stdInput.readLine()) != null) {
	        	//Log.i(TAG, "STANDARD OUTPUT: "+s);
	        	if (s.startsWith("rtt")){
	        		String [] line = s.split(" ");
	        		pingOutput = line[3].replaceAll("/", ",");
	        		System.out.println(pingOutput);
	        	}
	        }
	        while ((s = stdError.readLine()) != null) {
	        	Log.e(TAG, "STANDARD ERROR: "+s);
	        }
	        Date now = new Date();
	        String toWrite = now.getTime()+","+pingOutput+","+getLocationGSM()+","+
	    			String.valueOf(tm.getNetworkType())+","+snrlistener.readValue();
        	writeData(filenamePing, toWrite);
	        Log.i(TAG, toWrite);

			
        } 
        catch (Exception e) {
            Log.d(TAG, "request failed: " + e);
            //Write timeout!
            
        } 
	}
	
    class TxRxThread extends Thread {
    	public static final String TH_TAG="TX_DATA";
    	TxRxThread() {

        }
        public void run() {        
        	while (true){
        		try{
                	Date now = new Date();	
                	String toWrite = now.getTime()+","+dataTxInfo()+","+
                			getLocationGSM()+","+String.valueOf(tm.getNetworkType())+","+snrlistener.readValue();
                	Log.i(TH_TAG, toWrite);
                	writeData(filenameTraffic, toWrite);

    				try{
    		         	Thread.sleep(2000);    		         	
    				}
    				catch(Exception e){
    					System.out.println("Error: "+e.getMessage());
    				}
                	
        		}
        		catch(Exception e){
        			System.out.println("Exception: "+e.getMessage());
        		}
        	}
        }
    }
    
	/*
	 * Listener for signal strength
	 */
	public class SignalStateListener extends PhoneStateListener{
		
		private int signalStrength;
		
		public SignalStateListener (int signalStrength){
			this.signalStrength = signalStrength;
		}
		
		public void onSignalStrengthChanged(int asu){
			this.signalStrength = asu;
			Log.e(TAG, "[[[[SIGNAL STRENGTH CHANGE]]]]  ----> ASU: "+asu);
			
		}
		
		public int readValue(){
			return this.signalStrength;
		}		
	}
	
	public String getLocationGSM (){
		String [] ret = new String [2];		
		try{
			GsmCellLocation gsmLoc = (GsmCellLocation) tm.getCellLocation();
			return String.valueOf(gsmLoc.getCid())+","+String.valueOf(gsmLoc.getLac());	
		}
		catch(Exception e){
			return "-1,-1";
		}
	}


    public synchronized void writeData ( String filename, String data){
    	Log.i(TAG, "On write data: "+filename);
        try{
                File root = Environment.getExternalStorageDirectory();
                if (root.canWrite()){
                		Log.i(TAG, "Ready to write");
                		File f = new File (root, filename);
                        FileWriter fw = new FileWriter(f, true);
                        BufferedWriter out = new BufferedWriter (fw);
                        Date now = new Date();
                        String toWrite = data+"\n";
                        out.write(toWrite);
                        out.close();
                }
                else{
                	Log.i(TAG, "COULDN'T WRITE");
                }
        }
        catch(Exception e){
                Log.e(TAG, "Could not write file: "+e.getMessage());
        }
    }    
    
    public static String readFile(String file){
        ProcessBuilder cmd;
        String result = "";
        try{
                String[] args = {"/system/bin/cat", file};
                cmd = new ProcessBuilder(args);

                Process process = cmd.start();
                InputStream in = process.getInputStream();
                byte[] re = new byte [1024];
                while (in.read(re)!=-1){

                        //Log.e(TAG, "ReadCPUInfo: "+new String(re));
                        result = result+new String (re);
                }
                in.close();
        }
        catch(Exception e){
                e.printStackTrace();
        }
        return result;
    }
    
	public String dataTxInfo (){
		String retValues = null;
		String [] line = readFile("/proc/net/dev").split("\n");
		int limit = 10;
		if (line.length<10){
			limit = line.length;
		}
		for (int i=1; i<limit; i++){			
			String [] splitLine = line[i].split(" ");
			String [] val = new String[12];
			int h=0;
			for (int j = 0; j<splitLine.length; j++){
				if (h==10){
					break;
				}
				if (splitLine[j].equalsIgnoreCase("")){
					continue;
				}
				val[h] = splitLine[j];
				h++;
			}
			if (val[0].startsWith("rmnet0")){
				long currentRxVal = prevRxMnet0;
				long currentTxVal = prevTxMnet0;				
				String [] head = val[0].split(":");
				if (head.length==2){
					currentRxVal = Long.parseLong(head[1]);
					currentTxVal = Long.parseLong(val[8]);					
				}
				else{
					currentRxVal = Long.parseLong(val[1]);
					currentTxVal = Long.parseLong(val[9]);
				}
				long deltaRx = currentRxVal- prevRxMnet0;
				long deltaTx = currentTxVal - prevTxMnet0;
				
				prevRxMnet0 = currentRxVal;
				prevTxMnet0 = currentTxVal;
				retValues = prevRxMnet0+","+prevTxMnet0;
			}
		}		
		return retValues;		
	}
	

	/**
	 * Listeners
	 */	
	GpsStatus.Listener gpsListener = new GpsStatus.Listener() {
		
		public void onGpsStatusChanged(int event) {
			// TODO Auto-generated method stub
			if (event == GpsStatus.GPS_EVENT_FIRST_FIX){
				Date now = new Date();
				long currentTime = now.getTime()-startTime;
				Log.e(TAG, "GPS_EVENT_FIRST_FIX. First fix happened at "+currentTime);
			}
			
			if (event == GpsStatus.GPS_EVENT_SATELLITE_STATUS){
				Date now = new Date();
				long currentTime = now.getTime()-startTime;
				Log.e(TAG, "GPS_EVENT_SATELLITE_STATUS EVENT. Happened at "+currentTime);
			}
			if (event == GpsStatus.GPS_EVENT_STARTED){
				Log.e(TAG, "GPS Started");
				writeData("GPS_START", "");
			}
			if (event == GpsStatus.GPS_EVENT_STOPPED){
				Log.e(TAG, "GPS Stopped");
				writeData("GPS_STOP", "");
			}
		}
	};
	

	
	public class GpsLocHandler implements LocationListener {
		private double gpsLat = -1;
		private double gpsLong = -1;
		private double accuracy = -1;
		
		public void onLocationChanged (Location loc){
			gpsLat = loc.getLatitude();
			gpsLong = loc.getLongitude();
			accuracy = loc.getAccuracy();
			Date now = new Date();
			long currentTime = now.getTime()-startTime;
			Log.e(TAG, "GpsLocHandler - locationChanged to "+gpsLat+"/"+gpsLong+"/"+accuracy);
			writeData(filenameLoc, currentTime+"\t"+gpsLat+"\t"+gpsLong+"\t"+accuracy);
		}
		

		public void onProviderDisabled(String arg0) {
			// TODO Auto-generated method stub
			Log.e(TAG, "GPSLocHandler - onProviderDisabled");

			writeData("GPS_PROVIDER_DISABLED", arg0);
		}

		public void onProviderEnabled(String arg0) {
			// TODO Auto-generated method stub
			Log.e(TAG, "GPSLocHandler - onProviderEnabled");
			writeData("GPS_PROVIDER_ENABLED", arg0);
			
		}

		public void onStatusChanged(String arg0, int arg1, Bundle arg2) {
			// TODO Auto-generated method stub
			Log.e(TAG, "GPSLocHandler - onStatusChanged");
			writeData("GPS_STATUS_CHANGED", arg0+"\t"+arg1);
			
		}
	};
	

}

package cl.signpo.st;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;


public class PingParser {
	public static final String TAG = "PING";
	public static final boolean DEBUG = false;
	
	/*
	 * Processes a ping file. It needs the current scenario and the role
	 * which are obtained from the folder name
	 * 
	 */
	public static void parsePing(File f, String outputFileName, int scenario, int role, String toIp){
		String filename = f.getName();
		
		try{
			// Open the file that is the first 
			// command line parameter
			FileInputStream fstream = new FileInputStream(f);
			// Get the object of DataInputStream
			DataInputStream in = new DataInputStream(fstream);
			BufferedReader br = new BufferedReader(new InputStreamReader(in));
			String strLine;
			//Read File Line By Line
			while ((strLine = br.readLine()) != null)   {
				// Print the content on the console
				//System.out.println (strLine);
				if (strLine.startsWith("PING")){
					continue;
				}
				String [] strSplit = strLine.split(" ");				
				String fromIp = strSplit[3].substring(0, strSplit[3].length()-1);
				String latency = strSplit[6].split("=")[1];
				String output = scenario+","+role+","+FilenameParser.getTimestamp(f)+","+FilenameParser.getTunnelId(f)+","+toIp+","+Tools.ipToInt(fromIp)+","+latency;
				Tools.writeFile(outputFileName, output);
						
			}
			//Close the input stream
			in.close();
		}
		catch (Exception e){//Catch exception if any//Catch exception if any
			System.err.println("Error: " + e.getMessage());
			System.out.println("File: "+f.getAbsolutePath());
			System.exit(-1);
		}
	}
}

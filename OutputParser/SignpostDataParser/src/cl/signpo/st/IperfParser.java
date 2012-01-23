package cl.signpo.st;


import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;

public class IperfParser {
	
	public static final boolean DEBUG = false;
	
	public static void parseIperfUDP(File f, String outputFileName, int scenario, int client){
		if (DEBUG) System.out.println("Processing IPERF_UDP: "+f.getName());
		int tunnelId = FilenameParser.getTunnelId(f);
		String timeStamp = FilenameParser.getTimestamp(f);
		try{
			FileInputStream fstream = new FileInputStream(f);
			// Get the object of DataInputStream
			DataInputStream in = new DataInputStream(fstream);
			BufferedReader br = new BufferedReader(new InputStreamReader(in));
			String strLine;
			//Read File Line By Line
			String remoteIp = null;
			String localIp = null;
			String downstream = null;
			String upstream = null;
			boolean startProcessing = false;
			while ((strLine = br.readLine()) != null)
			{
				if (strLine.contains(" datagrams") || strLine.contains("Server Report") || strLine.contains("(null)s") || strLine.contains("GBytes")){
					continue;
				}
				//Need to get the Remote endpoint IP
				if (strLine.startsWith("Client")){
					String [] lineSplit = strLine.split(" ");
					remoteIp = lineSplit[3].substring(0, lineSplit[3].length()-1);
					if (remoteIp.equalsIgnoreCase("localhost")){
						remoteIp = "127.0.0.1";
					}
				}
				//Need to get local IP and also the IDS used by IPERF to identify the
				//streams
				else if (strLine.startsWith("[ ") && strLine.contains(" port")){
					if (strLine.contains("local ")){
						localIp=strLine.split(" ")[4];
					}					
					if (strLine.endsWith(remoteIp+" port 5001") || strLine.endsWith(remoteIp+" port 6001") ){
						upstream = strLine.substring(0, 5);
					}
					else{
						downstream = strLine.substring(0, 5);
					}
				}
				else if (strLine.startsWith("[ ID]")){
					continue;
				}
				else if (strLine.startsWith("[") && remoteIp==null){
					if (DEBUG) System.out.println (strLine);
					System.out.println("Error!!!!!!! Corrupted IPERF UDP file. Missing header in iperf file");
					System.exit(-1);
				}
				
				if (downstream!=null && upstream!=null){
					if (strLine.contains("connected with")){
						continue;
					}
					String [] line = strLine.split("\\s+");
					if (line.length<10){
						if (DEBUG) System.out.println("----REMOVED: "+strLine);
						continue;
					}
					if (strLine.startsWith(downstream)){
						if (DEBUG) System.out.println("I << "+strLine);
						String toPrint = processUdpLine(strLine, f);
						if (toPrint !=null){
							String processLine = scenario+","+client+","+timeStamp+","+tunnelId+","+Tools.ipToInt(localIp)+","+Tools.ipToInt(remoteIp)+","+toPrint;
							Tools.writeFile(outputFileName, processLine);
							if (DEBUG) System.out.println("I << "+processLine);							
						}
					}
					if (strLine.startsWith(upstream)){
						if (DEBUG) System.out.println("O << "+strLine);
						String toPrint = processUdpLine(strLine, f);
						if (toPrint !=null){
							String processLine = scenario+","+client+","+timeStamp+","+tunnelId+","+Tools.ipToInt(localIp)+","+Tools.ipToInt(remoteIp)+","+toPrint;
							Tools.writeFile(outputFileName, processLine);
							if (DEBUG) System.out.println("O << "+processLine);							
						}
						
					}
				}
			}
			//Close the input stream
			in.close();
		}
		catch (Exception e){
			//Catch exception if any//Catch exception if any
			System.err.println("Error: " + e.getMessage());
			System.out.println("File: "+f.getAbsolutePath());
			System.exit(-1);
		}
	}

	/*
	 * Parse IPERF TCP
	 */
	public static void parseIperfTCP(File f, String outputFileName, int scenario, int client){
		if (DEBUG) System.out.println("Processing IPERF_TCP: "+f.getName());

		int tunnelId = FilenameParser.getTunnelId(f);
		String timeStamp = FilenameParser.getTimestamp(f);
		
		try{
			// Open the file that is the first 
			// command line parameter
			FileInputStream fstream = new FileInputStream(f);
			// Get the object of DataInputStream
			DataInputStream in = new DataInputStream(fstream);
			BufferedReader br = new BufferedReader(new InputStreamReader(in));
			String strLine;
			//Read File Line By Line
			String remoteIp = null;
			String localIp = null;
			String downstream = null;
			String upstream = null;
			boolean startProcessing = false;
			
			while ((strLine = br.readLine()) != null)   {
				// Print the content on the console
				if (strLine.contains(" datagrams") || strLine.contains("Server Report") || strLine.contains("(null)s") || strLine.contains("GBytes")){
					continue;
				}
				//Need to get the Remote endpoint IP
				if (strLine.startsWith("Client")){
					String [] lineSplit = strLine.split(" ");
					remoteIp = lineSplit[3].substring(0, lineSplit[3].length()-1);
					if (remoteIp.equalsIgnoreCase("localhost")){
						remoteIp = "127.0.0.1";
						System.out.println("Connecting to localhost --> ssh tunnel?");
					}
				}
				//Need to get local IP and also the IDS used by IPERF to identify the
				//streams
				else if (strLine.startsWith("[ ") && strLine.contains(" port")){
					if (strLine.contains("local ")){
						localIp=strLine.split(" ")[4];
						System.out.println(" Local IP: "+localIp);
					}
					if (strLine.endsWith(remoteIp+" port 5001") || strLine.endsWith(remoteIp+" port 6001") ){
						upstream = strLine.substring(0, 5);
						System.out.println("UPSTREAM ID: "+upstream);
					}
					else{
						downstream = strLine.substring(0, 5);
						System.out.println("DOWNSTREAM ID: "+downstream);
					}
				}
				else if (strLine.startsWith("[ ID]")){
					continue;
				}
				else if (strLine.startsWith("[") && remoteIp==null){
					if (DEBUG) System.out.println (strLine);
					System.out.println("Error!!!!!!! Corrupted IPERF TCP file. Missing header in iperf file");
					System.exit(-1);
				}				

				if (downstream!=null && upstream!=null){
					if (strLine.contains("connected with")){
						continue;
					}					
					if (strLine.startsWith(downstream)){
						if (DEBUG) System.out.println("I << "+strLine);
						String processLine = scenario+","+client+","+timeStamp+","+tunnelId+","+Tools.ipToInt(localIp)+","+Tools.ipToInt(remoteIp)+","+processTcpLine(strLine);
						Tools.writeFile(outputFileName, processLine);
						if (DEBUG) System.out.println("I << "+processLine);
					}
					if (strLine.startsWith(upstream)){
						if (DEBUG) System.out.println("O << "+strLine);
						String processLine = scenario+","+client+","+timeStamp+","+tunnelId+","+Tools.ipToInt(localIp)+","+Tools.ipToInt(remoteIp)+","+processTcpLine(strLine);
						Tools.writeFile(outputFileName, processLine);
						if (DEBUG) System.out.println("O << "+processLine);
					}
				}
			}
			//Close the input stream
			in.close();
		}
		catch (Exception e){//Catch exception if any
			System.err.println("Error: " + e.getMessage());
			System.exit(-1);
		}
	}	
	
	
	public static long processTcpLine(String strLine){
		if (DEBUG) System.out.println("FINDING BW FOR: "+strLine);
		String [] line = strLine.split("\\s+");
		double bw = 0.0;						
		if (line[6].contains("Bytes")){
			bw = Double.parseDouble(line[7]);
			if (DEBUG) System.out.println("READ VALUE: "+bw);
			if (line[8].equalsIgnoreCase("Mbits/sec")){
				bw = bw*1024.0*1024.0;
			}
			if (line[8].equalsIgnoreCase("Kbits/sec")){
				bw = bw*1024.0;
			}
		}
		else{
			bw = Double.parseDouble(line[6]);
			if (line[7].equalsIgnoreCase("Mbits/sec")){
				bw = bw*1024.0*1024.0;
			}
			if (line[7].equalsIgnoreCase("Kbits/sec")){
				bw = bw*1024.0;
			}
		}
		return Math.round(bw);		
	}
	
	/*
	 * UDP Line Process
	 */
	public static String processUdpLine (String strLine, File f){
		String [] line = strLine.split("\\s+");
		double bw = 0.0;
		double jitter = 0.0;
		long missedDatagrams = 0;
		long totalDatagrams = 0;						
		if (line[6].contains("Bytes")){
			bw = Double.parseDouble(line[7]);
			if (line[8].equalsIgnoreCase("Mbits/sec")){
				bw = bw*1024.0*1024.0;
			}
			if (line[8].equalsIgnoreCase("Kbits/sec")){
				bw = bw*1024.0;
			}
			
			
			jitter = Double.parseDouble(line[9]);
			try{
				missedDatagrams = Long.parseLong(line[11].substring(0, line[11].length()-1));
				totalDatagrams = Long.parseLong(line[12]);
			}
			catch(Exception e){
				System.out.println("WARNING: "+e.getMessage());
				System.out.println("File: "+f.getAbsolutePath());
				System.out.println("In line: "+strLine);
				String [] breakTxDatagramsString = line[11].split("/");
				missedDatagrams = Long.parseLong(breakTxDatagramsString[0]);
				totalDatagrams = Long.parseLong(breakTxDatagramsString[1]);
			}
		}
		else{
			bw = Double.parseDouble(line[6]);
			if (line[7].equalsIgnoreCase("Mbits/sec")){
				bw = bw*1024.0*1024.0;
			}
			if (line[7].equalsIgnoreCase("Kbits/sec")){
				bw = bw*1024.0;
				
			}
			
			jitter = Double.parseDouble(line[8]);
			try{
				missedDatagrams = Long.parseLong(line[10].substring(0, line[10].length()-1));
				totalDatagrams = Long.parseLong(line[11]);								
			}
			catch(Exception e){
				System.out.println("WARNING: "+e.getMessage());
				System.out.println("File: "+f.getAbsolutePath());
				System.out.println("In line: "+strLine);
				String [] breakTxDatagramsString = line[10].split("/");
				missedDatagrams = Long.parseLong(breakTxDatagramsString[0]);
				totalDatagrams = Long.parseLong(breakTxDatagramsString[1]);
			}
		}
		if (bw == 0){
			return null;
		}
		return ""+Math.round(bw)+","+totalDatagrams+","+missedDatagrams+","+jitter;
	}
}


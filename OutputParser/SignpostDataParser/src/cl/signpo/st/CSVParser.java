package cl.signpo.st;

import java.io.BufferedReader;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;

public class CSVParser {

	public static final boolean DEBUG = true;
	
	public static void ParseCSVFile (File f, String outputTcpTrace, int scenario, int client){
		System.out.println("Processing PCAP file: "+f.getAbsolutePath());
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
				if (DEBUG) System.out.println (strLine);
				if (strLine.startsWith("#") || strLine.startsWith("conn_#") || strLine.equals("")){ 
					System.out.println("Header Line: ");
					continue;
				}
				//Uncomment to print list of params
				/*
				else if ( strLine.startsWith("conn_#")){
					String [] items = strLine.split(",");
					for (int i=0; i<items.length; i++){
						System.out.println(i+" - "+items[i]);
					}
				}
				*/
				
				else {
					String [] items = strLine.split(",");
					String hostA = items[1];
					String hostB = items[2];
					String portA = items[3];
					String portB = items[4];
					double jitterAB = Double.parseDouble(items[93])-Double.parseDouble(items[91]);
					double jitterBA = Double.parseDouble(items[94])-Double.parseDouble(items[92]);
					//Get A->B
					String outputLine_A2B = scenario+","+client+","+Tools.ipToInt(hostA) +","+Tools.ipToInt(hostB)+","+portA+","+portB+
							","+items[7]+","+items[35]+","+items[129]+","+items[61]+","+items[63]+","+items[67]+
							","+items[87]+","+items[91]+","+items[93]+","+items[95]+","+items[97]+","+jitterAB;
					System.out.println(outputLine_A2B);
					Tools.writeFile(outputTcpTrace, outputLine_A2B);
					//Get B->A
					String outputLine_B2A = scenario+","+client+","+Tools.ipToInt(hostB) +","+Tools.ipToInt(hostA)+","+portB+","+portA+
							","+items[8]+","+items[36]+","+items[130]+","+items[62]+","+items[64]+","+items[68]+
							","+items[88]+","+items[92]+","+items[94]+","+items[96]+","+items[98]+","+jitterBA;
					System.out.println(outputLine_B2A);
					Tools.writeFile(outputTcpTrace, outputLine_B2A);

				}
			}
			//Close the input stream
			in.close();
		}catch (Exception e){//Catch exception if any
			System.err.println("Error: " + e.getMessage());
			System.out.println("File: "+f.getAbsolutePath());
			System.exit(-1);
		}
	}
}

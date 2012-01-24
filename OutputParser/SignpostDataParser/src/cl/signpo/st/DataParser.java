package cl.signpo.st;

import java.io.File;
import java.io.FileFilter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class DataParser {

	//Conf
    public static final String fileName = "app.config";
    public static final String pingPattern = "ping";
    public static final String iperfPattern = "iperf";
    public static final String tcpdumpPattern = "pcap";
    public static final String tcpdumpPatternEdit = ".csv";
    public static final String pttcpPattern = "pttcp";
    public static final String outputPing = "outputPing";
    public static final String outputFolder =	"outputFolder";

    
    public static String outputPingFilename;
    public static String outputUdpIPerfFilename;
    public static String outputTcpIPerfFilename;
    public static String outputTcpTrace;
    public static String outputPath;
    
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		// TODO Auto-generated method stub


	    Properties prop = new Properties();
	    InputStream is;
	    String sourcePath;
	    
		try {
			is = new FileInputStream("parser.conf");
			prop.load(is);
			sourcePath = prop.getProperty("sourcepath");
			outputPingFilename = prop.getProperty("outputPing");
			outputUdpIPerfFilename = prop.getProperty("outputUdpPerf");
			outputTcpIPerfFilename = prop.getProperty("outputTcpPerf");
			outputTcpTrace = prop.getProperty("outputTcpTrace");
			outputPath = prop.getProperty(outputFolder);
			System.out.println("Source Path: "+sourcePath);
			System.out.println("Output path: "+outputPath);
			System.out.println("outputPingFilename Path: "+outputPingFilename);
			System.out.println("outputUdpIPerfFilename Path: "+outputUdpIPerfFilename);
			System.out.println("outputTcpIPerfFilename Path: "+outputTcpIPerfFilename);
			parseFolder(sourcePath);
		} catch (Exception e1) {
			// TODO Auto-generated catch block
			System.out.println("Error reading conf file: "+e1.getMessage());
			e1.printStackTrace();
			System.exit (-1);
		}
	}
	
	public static void parseFolder(String folder){
		//Gets all folders from config file and go over them (client and server). 
		//Get IPs from config file
		//lab-lab-eth
		String subfolder;
		int scenario;
		String [] setsubfolders;
		//LAB TO LAB
		subfolder= "lab-lab-eth";
		scenario =1;
		scansubfolders(folder, subfolder, scenario);	
		subfolder= "lab-ec2-eth";
		scenario =2;
		scansubfolders(folder, subfolder, scenario);
		subfolder= "lab-home-eth";
		scenario =3;
		scansubfolders(folder, subfolder, scenario);
		subfolder= "lab-wifi-eth";
		scenario =4;
		scansubfolders(folder, subfolder, scenario);
		subfolder= "lab-ec2-IPSEC";
		scenario =5;
		scansubfolders(folder, subfolder, scenario);
		subfolder= "3g3Mobile-ec2-eth";
		scenario =6;
		scansubfolders(folder, subfolder, scenario);	
		subfolder= "3gTMobile-ec2-eth";
		scenario =7;
		scansubfolders(folder, subfolder, scenario);	
		subfolder= "lab-ucs-eth";
		scenario =8;
		scansubfolders(folder, subfolder, scenario);		
	}

	public static void scansubfolders(String folder, String scenarioFolder, int scenario){
		String [] subfolders = {"client", "server"};
		
		String [] ret = new String[2];
		for (int i=0; i<2; i++){
			ret[i]=folder+"/"+scenarioFolder+"/"+subfolders[i];
			//Get in the properties file the scenario
			//Get local IP (client or server)
			String ip;
			Properties prop = new Properties();
		    InputStream is;
		    
			try {
				is = new FileInputStream("parser.conf");
				prop.load(is);
				ip = prop.getProperty(scenarioFolder+"_"+subfolders[i]);
				System.out.println("Scanning folder: "+subfolders[i]+" Client: "+scenario+", IP: "+ip+" Client(0)/Server(1): "+i);
				System.out.println("Path> "+ret[i]);
				parseFiles(ret[i], ip, scenario, i);
			}
			catch(Exception e){
				System.out.println("Exception "+e.getMessage());
				System.out.println("Couldn't process folder: "+ret[i]);
			}
		}	
	}
	
	/*
	 * Parses all the ping files for this experiment.
	 */
	public static void parseFiles (String folder, String ip, int scenario, int client){
		System.out.println(" Files in folder: "+folder);
		File [] files = getFilesInFolder(folder);
		for (int i=0; i<files.length; i++){
			if (files[i].isDirectory()){
				continue;
			}
			if(files[i].getName().contains(tcpdumpPattern)){
				System.out.println(files[i]+" RAW PCAP FILE. CONTINUE");
				continue;				
			}
			else if (files[i].getName().contains(pingPattern)){
				System.out.println(files[i]+" Parse PING");
				PingParser.parsePing(files[i], outputPath+outputPingFilename, scenario, client, ip);
			}
			else if(files[i].getName().contains(tcpdumpPatternEdit)){
				boolean isClient=true;
				if (isClient){
					if(files[i].getName().contains("udp")|| files[i].getName().contains("Udp")){
						System.out.println("UDP PCAP FILE");
						continue;
					}
					else{
						System.out.println(files[i]+" Parse TCPTRACE");
						CSVParser.ParseCSVFile(files[i], outputPath+outputTcpTrace, scenario, client);						
					}	
				}
			}
			else if(files[i].getName().contains(iperfPattern)){
				if (files[i].getName().contains("udp") ){
					System.out.println(files[i]+" Parse UDP IPERF");	
					IperfParser.parseIperfUDP(files[i], outputPath+outputUdpIPerfFilename, scenario, client);
				}
				else if (files[i].getName().contains("tcp")){
					System.out.println(files[i]+" Parse TCP IPERF");	
					IperfParser.parseIperfTCP(files[i], outputPath+outputTcpIPerfFilename, scenario, client);					
				}
			}
			else{
				System.out.println(files[i]+" UNKNOWN FORMAT");
			}
		}
	}

	

	/*
	 * Returns all the files in current directory
	 */
	public static File [] getFilesInFolder (String path){
		File folder = new File(path);
		System.out.println(folder.getAbsolutePath());
		System.out.println("Number of files: "+folder.listFiles());
		return folder.listFiles(); 
	}
}

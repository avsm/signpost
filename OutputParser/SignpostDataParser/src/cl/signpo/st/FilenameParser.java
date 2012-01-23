package cl.signpo.st;

import java.io.File;

public class FilenameParser {
	public static int getTunnelId (File f){

		String tunnel = f.getName().split("-")[2];
		if (tunnel.equalsIgnoreCase("direct")){
			return 0;
		}
		else if (tunnel.equalsIgnoreCase("iodine")){
			return 1;
		}
		else if (tunnel.equalsIgnoreCase("OpenVpn")){
			return 2;
		}
		else if (tunnel.equalsIgnoreCase("sshtunnel")){
			return 3;
		}
		//TODO: INCLUDE IPSEC!!!!
		System.out.println("Error processing header: "+f.getAbsolutePath());
		System.exit (-1);
		return -1;
	}
	
	public static String getTimestamp(File f){
		String filenameTime = f.getName().split("-")[3];
		return filenameTime.substring(0, filenameTime.length()-4);
	}
	
	
}

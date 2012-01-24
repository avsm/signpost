package cl.signpo.st;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class Tools {


	public static Long ipToInt(String addr) {
        String[] addrArray = addr.split("\\.");
        long num = 0;
        for (int i=0;i<addrArray.length;i++) {
            int power = 3-i;
            num += ((Integer.parseInt(addrArray[i])%256 * Math.pow(256,power)));
        }
        return num;
    }
	
	public static void writeFile (String fileName, String line){
		try {
			File f = new File (fileName);
			FileWriter fw = new FileWriter(f, true);
			BufferedWriter output = new BufferedWriter (fw);
			output.write(line+"\n");
			output.flush();
			output.close();
			fw.close();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			System.out.println(e.getMessage());
			e.printStackTrace();
		}
	}
}

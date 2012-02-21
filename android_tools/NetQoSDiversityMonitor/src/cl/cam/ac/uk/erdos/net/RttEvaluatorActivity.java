package cl.cam.ac.uk.erdos.net;

import cl.cam.ac.uk.crowdGps.R;
import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.PowerManager;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.Button;

public class RttEvaluatorActivity extends Activity implements OnClickListener {
	
    private static final String TAG = "PING_ACT";

	private static PowerManager pmActivity = null;
	private static PowerManager.WakeLock wlActivity = null;
	private static Button button = null;
	
	
    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        

        try{
        	Log.i(TAG, "Creating button");
            button = (Button) findViewById(R.id.button1);
            button.setOnClickListener(this);
        }
        catch(Exception e){
        	Log.e(TAG, "ERROR CREATING BUTTONS"+e.getMessage());
        }


        try{
        	Process root = Runtime.getRuntime().exec("su");
        }
        catch(Exception e ){
        	e.printStackTrace();
        }
		Log.e(TAG, "Power Manager created");


    }

	public void onClick(View v) {
		// TODO Auto-generated method stub
		Log.i(TAG, "Click!!!!");
    	switch (v.getId()){
    		case R.id.button1:
    			Log.e(TAG, "Button pressed");
    			//Start service
    			RttEvaluationService.setMainActivity(RttEvaluatorActivity.this);
				startService(new Intent(this, RttEvaluationService.class));
	    		break;
    	}
		
	}
	
	
	
    public void onDestroy(){
    	Log.i(TAG, "ACTIVITY ON DESTROY!!!!!");
    	super.onDestroy();
    }

}
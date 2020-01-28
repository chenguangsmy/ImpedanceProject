/*  
 * This file includes code to control asynchronous control of the robot
 * 
 * included are:
 * 
 * recoverBurt -> recovers burt to home position upon error
 * 
 * movetoCenter -> moves the burt to a predefined center postion
 * 
 * moveAstep -> moves the burt one step toward a position
 * 
 * Author(s): Ivana Stevens 2019
 * 
 */
 
#include "/home/robot/src/Proficio_Systems/magnitude.h"
#include "/home/robot/src/Proficio_Systems/normalize.h"
#include "/home/robot/rg2/include/RTMA_config.h"
#include <unistd.h>

#include <RTMA/RTMA.h>
#include "movingBurt.h"
#include "hapticsDemoClass.h"

#include <string>
#include <signal.h>
#include <typeinfo>
#include <iostream>
#include <fstream>
#include <time.h>
#include <stdio.h>
#include <pthread.h>
#include <ctime>

#include <cmath>
#include <math.h>
#include <Eigen/Core>
#include <barrett/detail/ca_macro.h>
#include <barrett/systems/abstract/haptic_object.h>

#include <boost/ref.hpp>
#include <boost/bind.hpp>
#include <boost/tuple/tuple.hpp>

#include <barrett/detail/stl_utils.h>  // waitForEnter()

#include <barrett/log.h>
#include <barrett/math.h>
#include <barrett/units.h>
#include <barrett/config.h>
#include <barrett/systems.h>
#include <barrett/exception.h>
#include <proficio/systems/utilities.h>
#include <barrett/products/product_manager.h>

// Networking
#include <netinet/in.h>
#include <sys/types.h>

#include <proficio/systems/utilities.h>

BARRETT_UNITS_FIXED_SIZE_TYPEDEFS;
BARRETT_UNITS_TYPEDEFS(6);


//extern bool yDirectionError;
extern bool forceMet; //thresholdMet;
//extern double forceThreshold;


/**
 * Thread funtion to handle messages from RTMA 
 */
template <size_t DOF>
void respondToRTMA(barrett::systems::Wam<DOF>& wam,
              cp_type system_center,
              RTMA_Module &mod,
              HapticsDemo<DOF> &ball)
{
  cf_type cforce;
  bool wamLocked = false;
  
  
  bool freeMoving = false; //TODO: THIS SHOULD BE FALSE
  cp_type cp;
  cv_type cv;
  //the system_center is the cp_type center_pos(0.5, -0.120, 0.250);
  cp_type monkey_center(system_center);
  cp_type target;

	CMessage Consumer_M;

  while (true)  // Allow the user to stop and resume with pendant buttons
  {
    // Read Messages
    mod.ReadMessage( &Consumer_M);

    // Send Position Data, no data will be sent when in state 1 (begin, before present)
    if (Consumer_M.msg_type == MT_SAMPLE_GENERATED && !freeMoving)
    {
      MDF_SAMPLE_GENERATED sample_generated_data;
      Consumer_M.GetData(&sample_generated_data);
      //TODO: check type
      MDF_BURT_STATUS burt_status_data;
      
      burt_status_data.sample_header = sample_generated_data.sample_header;
      //burt_status_data.timestamp = getTimestamp();
      //burt_status_data.state = thresholdMet;
      //burt_status_data.error = (int) hasError;

      // Set Force Data
      // The force data is not populated, these values are always 0 for now.
      burt_status_data.force_x = cforce[1];
      burt_status_data.force_y = cforce[0];
      burt_status_data.force_z = cforce[2];

      // Set Position Data  TODO: MOVE CONVERSION ELSEWHERE
      //Populate the pos data from wam, bounded by 9.999,
      //cp is in x,y,z order but populated to y,x,z.
      //x and y axis are reverted to match real coordinates?
      cp = barrett::math::saturate(wam.getToolPosition(), 9.999);
      burt_status_data.pos_x = cp[1]; // * 1280 / 0.2; // Assume this is accurate
      burt_status_data.pos_y = cp[0]; // * 1280 / 0.2; // TODO: check that cp has the right value
      burt_status_data.pos_z = cp[2]; // * 1280 / 0.2; // and is set properly

      //populate velocity here
      cv = barrett::math::saturate(wam.getToolVelocity(), 19.999);
	  burt_status_data.vel_x = cv[1]; // * 1280 / 0.2; // Assume this is accurate
	  burt_status_data.vel_y = cv[0]; // * 1280 / 0.2; // TODO: check that cp has the right value
	  burt_status_data.vel_z = cv[2]; // * 1280 / 0.2; // and is set properly

	  //also populate the center location
	  burt_status_data.center_x = system_center[1];
	  burt_status_data.center_y = system_center[0];
	  burt_status_data.center_z = system_center[2];

      // Send Message
      CMessage M( MT_BURT_STATUS );
      M.SetData( &burt_status_data, sizeof(burt_status_data) );
      mod.SendMessage( &M );
    }

    // Task State config, set force
    if (Consumer_M.msg_type == MT_TASK_STATE_CONFIG)
    {
      MDF_TASK_STATE_CONFIG task_state_data;
      Consumer_M.GetData( &task_state_data);
      cout << "task id : " << task_state_data.id << endl;
      freeMoving = false;
      
      switch(task_state_data.id) //cases are task state: begin, present, forceramp, move, hold, end, reset
      {
        case 1:
          freeMoving = true;
          ball.setForceMet(true);
          monkey_center[1] = task_state_data.target[30];
          monkey_center[0] = task_state_data.target[31];
          monkey_center[2] = task_state_data.target[32];
          ball.setCenter(monkey_center);
          break;
        case 2:
          break;
        case 3:
          wam.idle();
          ball.setForceMet(false);
          wamLocked = false;
          //forceThreshold = 0; //task_state_data.target[3]; //TODO: SEND FROM JUDGE MESSAGE? OR SEPARTE CONFIGURE
          cout << "force threshold is: " << task_state_data.target[3] << endl;
          break;
        case 4:
          ball.setForceMet(true);
          break;
        case 5:
          break;
        case 6:
        case 7:
          freeMoving = true;
          ball.setForceMet(true);
          /*Shuqi Liu - 2019/10/09-19:01 Stay at current location*/
          if (!wamLocked)
          {
            cout << "Locking Wam" << endl;
            wam.moveTo(wam.getToolPosition());
            wamLocked = true;
          }
          /*
          target[1] = task_state_data.target[0];
          target[0] = task_state_data.target[1];
          target[2] = task_state_data.target[2];
          cout << "Target : " << target[0] << "," << target[1] << "," << target[2] << endl;

          wam.moveTo(target);*/
          break;
        default:
          break;
      }      
      cout << monkey_center << endl;
    }

    // Have Burt move toward home position using the default moveTo speed.
    else if (Consumer_M.msg_type == MT_MOVE_HOME && freeMoving)
    {
      MDF_MOVE_HOME startButton;
      Consumer_M.GetData( &startButton);
      moveToCenter(wam, monkey_center, mod);
    }

    // Ping sent   Acknowlegde ping...
    else if (Consumer_M.msg_type == MT_PING) {}

    // Exit the function
    else if (Consumer_M.msg_type == MT_EXIT) {}
  
    //if (yDirectionError) { /*cout << "Y direction Error" << endl;*/ }
  }
}

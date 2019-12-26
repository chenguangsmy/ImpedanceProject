/* Simple demo showing how to communicate with Net F/T using C language. */

#ifdef _WIN32
	#include <winsock2.h>
	#include <ws2tcpip.h>
	#pragma comment(lib, "Ws2_32.lib")
    #include <windows.h>
    
    #define strcasecmp _stricmp
    #define strncasecmp _strnicmp 
#else
	#include <arpa/inet.h>
	#include <sys/socket.h>
	#include <netdb.h>
    #include <unistd.h>
#endif

#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define PORT 49152 // Port the Net F/T always uses
#define COMMAND 2 // Command code 2 starts streaming
#define NUM_SAMPLES 1 // Will send 1 sample before stopping

#define DISP_MAX_CNT	60	// display force data once a second
#define AVG_MAX_CNT     10  // average 10 samples

#include "Dragonfly.h"
#include "Dragonfly_config.h"


/* Typedefs used so integer sizes are more explicit */
typedef unsigned int uint32;
typedef int int32;
typedef unsigned short uint16;
typedef struct response_struct {
	uint32 rdt_sequence;
	uint32 ft_sequence;
	uint32 status;
	int32 FTData[6];
} RESPONSE;

static Dragonfly_Module mod;

void wait(unsigned int milliseconds)
{
#ifdef _WIN32
    Sleep(milliseconds);
#else
    usleep(milliseconds * 1000);
#endif
}


int main ( int argc, char ** argv ) {
#ifdef _WIN32
	SOCKET socketHandle;		/* Handle to UDP socket used to communicate with Net F/T. */
	WSADATA wsaData;
    WORD wVersionRequested;
#else
	int socketHandle;			/* Handle to UDP socket used to communicate with Net F/T. */
#endif
	struct sockaddr_in addr;	/* Address of Net F/T. */
	struct hostent *he;			/* Host entry for Net F/T. */
	byte request[8];			/* The request data sent to the Net F/T. */
	RESPONSE resp;				/* The structured response received from the Net F/T. */
	byte response[36];			/* The raw response data received from the Net F/T. */
	int i;						/* Generic loop/array index. */
	int err;					/* Error status of operations. */
    int keep_going = 1;
    CMessage inMsg;

	if ( argc < 2 )
	{
		fprintf( stderr, "Usage: %s config mm_ip\n", argv[0] );
		return -1;
	}
    
#ifdef _WIN32
	wVersionRequested = MAKEWORD(2, 2);
    WSAStartup(wVersionRequested, &wsaData);
#endif

	// Calculate number of samples, command code, and open socket here.
	socketHandle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (socketHandle == -1) {
		fprintf(stderr, "Socket could not be opened.\n");
		exit(1);
	}
	
	*(uint16*)&request[0] = htons(0x1234); // standard header.
	*(uint16*)&request[2] = htons(COMMAND); // per table 9.1 in Net F/T user manual.
	*(uint32*)&request[4] = htonl(NUM_SAMPLES); // see section 9.1 in Net F/T user manual.
	
	// Sending the request.
	he = gethostbyname("192.168.1.1"); //(argv[1]);
	memcpy(&addr.sin_addr, he->h_addr_list[0], he->h_length);
	addr.sin_family = AF_INET;
	addr.sin_port = htons(PORT);
	
	err = connect( socketHandle, (struct sockaddr *)&addr, sizeof(addr) );
	if (err == -1) {
		exit(2);
	}
    
    mod.InitVariables(MID_NETBOX_MODULE, 0);  

    if( argc > 2) 
    {
        char *mm_ip = NULL;
        mm_ip = argv[2];
        printf("connecting to dragonfly at %s\n", mm_ip);
        mod.ConnectToMMM(mm_ip);
    }    
    else
    {
        printf("connecting to dragonfly\n");
        mod.ConnectToMMM();
    }
    
    mod.Subscribe(MT_EXIT);
    mod.Subscribe(MT_PING);
    mod.Subscribe(MT_SAMPLE_GENERATED);
    mod.Subscribe(MT_TASK_STATE_CONFIG);
    
    fprintf( stderr, "Connected to Dragonfly...\n");

    CMessage ForceSensorDataMsg( MT_FORCE_SENSOR_DATA);
    ForceSensorDataMsg.AllocateData( sizeof(MDF_FORCE_SENSOR_DATA));
    MDF_FORCE_SENSOR_DATA *force_data = (MDF_FORCE_SENSOR_DATA *) ForceSensorDataMsg.GetDataPointer();

    CMessage RawForceSensorDataMsg( MT_RAW_FORCE_SENSOR_DATA);
    RawForceSensorDataMsg.AllocateData( sizeof(MDF_RAW_FORCE_SENSOR_DATA));
    MDF_RAW_FORCE_SENSOR_DATA *raw_force_data = (MDF_RAW_FORCE_SENSOR_DATA *) RawForceSensorDataMsg.GetDataPointer();
    
	int disp_cnt = DISP_MAX_CNT;
    MDF_SAMPLE_GENERATED sample_gen;
    MDF_TASK_STATE_CONFIG tsc;
    double TempAvgForce[] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    double AvgForce[] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    int AvgCnt = 0;

    while(keep_going)
    {
        bool got_msg = mod.ReadMessage( &inMsg, 0.01);
        if( got_msg) 
        {
        
			if (inMsg.msg_type == MT_TASK_STATE_CONFIG)
            {
                inMsg.GetData(&tsc);
                if (tsc.id == 1)
                {
                    AvgCnt = 0;
                    for(i=0; i<6; i++)
                        TempAvgForce[i] = (double) 0.0;
                }
            }
        
            else if (inMsg.msg_type == MT_SAMPLE_GENERATED)
            {
                inMsg.GetData(&sample_gen);
            
                send( socketHandle, (const char *)request, 8, 0 );
                // Receiving the response
                recv( socketHandle, (char *)response, 36, 0 );

                raw_force_data->sample_header = sample_gen.sample_header;
                raw_force_data->rdt_sequence = ntohl(*(uint32*)&response[0]);
                raw_force_data->ft_sequence = ntohl(*(uint32*)&response[4]);
                raw_force_data->status = ntohl(*(uint32*)&response[8]);
                for( i = 0; i < 6; i++ ) {
                    int32 data; 
                    data = ntohl(*(int32*)&response[12 + i * 4]);
                    raw_force_data->data[i] = (double)(((double) data) / ((double) 1000000));
                }

                if (AvgCnt < AVG_MAX_CNT) 
                {
                    for( i = 0; i < 6; i++ ) {
                        TempAvgForce[i] = TempAvgForce[i] + raw_force_data->data[i];
                    }
                    
                    AvgCnt = AvgCnt + 1;
                }
                
                if (AvgCnt == AVG_MAX_CNT)
                {
                    for( i = 0; i < 6; i++ ) {
                        AvgForce[i] = TempAvgForce[i] / AVG_MAX_CNT;
                    }
                        
                    AvgCnt = AvgCnt + 1; // this will stop the averaging until next time
                }

                force_data->sample_header = sample_gen.sample_header;
                force_data->rdt_sequence = raw_force_data->rdt_sequence;
                force_data->ft_sequence = raw_force_data->ft_sequence;
                force_data->status = raw_force_data->status;

                for( i = 0; i < 6; i++ ) {
                    force_data->data[i] = raw_force_data->data[i] - AvgForce[i];
                    force_data->offset[i] = AvgForce[i];
                }

                disp_cnt++;
                if (disp_cnt >= DISP_MAX_CNT)
                {
                    // Output the response data
                    printf( "rdt: %08d   ", force_data->rdt_sequence );
                    printf( "ft : %08d   ", force_data->ft_sequence );
                    printf( "sta: 0x%08x   ", force_data->status );
                    printf("\n");
                    
                    printf( "RAW: ");
                    for (i =0;i < 6;i++) {
                        printf("%.2lf  ", raw_force_data->data[i]);
                    }
                    printf("\n");

                    printf( "OFS: ");
                    for (i =0;i < 6;i++) {
                        printf("%.2lf  ", AvgForce[i]);
                    }
                    printf("\n");

                    printf( "ADJ: ");
                    for (i =0;i < 6;i++) {
                        printf("%.2lf  ", force_data->data[i]);
                    }
                    printf("\n\n");

                    
                    disp_cnt = 0;
                }
                    
                mod.SendMessage(&RawForceSensorDataMsg);
                mod.SendMessage(&ForceSensorDataMsg);
                
                //wait(10); 
            }
            
			else if (inMsg.msg_type == MT_PING)
			{
				char MODULE_NAME[] = "NetboxModule";
				MDF_PING *pg = (MDF_PING *) inMsg.GetDataPointer();
				if ( (strcasecmp(pg->module_name, MODULE_NAME) == 0) || 
				   (strcasecmp(pg->module_name, "*") == 0) || 
				   (inMsg.dest_mod_id == mod.GetModuleID()) )
				{
					CMessage PingAckMessage( MT_PING_ACK);
					PingAckMessage.AllocateData( sizeof(MDF_PING_ACK));
					MDF_PING_ACK *pa = (MDF_PING_ACK *) PingAckMessage.GetDataPointer();

					memset(pa,0,sizeof(MDF_PING_ACK));        
					for (int i = 0; i < strlen(MODULE_NAME); i++)
					{
						pa->module_name[i] = MODULE_NAME[i];
					}

					mod.SendMessage( &PingAckMessage);
				}
			}
			else if (inMsg.msg_type == MT_EXIT)
			{
				if ((inMsg.dest_mod_id == 0) || (inMsg.dest_mod_id == mod.GetModuleID()))
				{
					printf("got exit!\n");
					mod.SendSignal(MT_EXIT_ACK);
					mod.DisconnectFromMMM();
					keep_going = 0;
					break;
				}
			}        
        }
    }

	/* Close socket */
#ifdef _WIN32
	closesocket(socketHandle);
#else
	close(socketHandle);
#endif
	return 0;
}

/* 21100103@handong.edu */

#include <opencv2/opencv.hpp>
#include <iostream>
#include "opencv2/core/core.hpp"
#include "opencv2/highgui/highgui.hpp" 
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/video/video.hpp"
#include "opencv2\features2d\features2d.hpp"
#include <vector>
#include <time.h>
#include <TCHAR.h>

//mask params
#define RED_MASK 0x0007
#define GREEN_MASK 0x038
#define BLUE_MASK 0x00C0

//vga resolution
#define WD 640
#define HG 480


//name space
using namespace std;
using namespace cv;


int _tmain(int argc, _TCHAR* argv[]) {

	char f_name[20];

	//read image
	cout << "Type your file name. It should be the full name" << endl;
	cout << "ex) dsd.bmp" << endl;
	cout << "The IMAGE file should be in the directory of this EXE file" << endl;
	cout << "BMP format is recommanded" << endl << endl << endl;
	cout << "File : ";
	cin >> f_name;
	cout << endl;

	Mat frame = imread(f_name, CV_LOAD_IMAGE_COLOR);
	Size size = frame.size();
	vector<Mat> planes(3);


	//vars
	int index = 0;
	unsigned short temp;
	int a = 0;
	float ratio = 0.0;

	//open txt file
	FILE* f = NULL;
	a = fopen_s(&f, "dsd.coe", "w");

	//print out origianl image

	cout << "width : " << size.width << endl;
	cout << "height : " << size.height << endl;

	if (size.width > WD || size.height > HG)
	{
		cout << "we need to resize the image you gave" << endl;

		//width
		if (size.width > WD)
		{
			ratio = WD*1.0 / (double)size.width;
			size.width = WD;
			size.height = (int)(((double)size.height) * ratio);
		}
		//height
		if (size.height > HG)
		{
			ratio = HG*1.0 / (double)size.height;
			size.height = HG;
			size.width = (int)(((double)size.width) * ratio);
		}
		resize(frame, frame, size);
		cout << "re width : " << size.width << endl;
		cout << "re height : " << size.height << endl;

	}
#if 1
	//split into 3 ch plane
	split(frame, planes);
	unsigned short r, g, b;


	/*write coe file*/
	fprintf(f, "memory_initialization_radix=16;\n");
	fprintf(f, "memory_initialization_vector=\n");
	for (int i = 0; i < size.height; i++) // vertical exploring
	{
		for (int j = 0; j < size.width; j++) // horizontal exploring
		{
			
			//get pixel data & normalizing & casting
			r = floor(planes[2].at<uchar>(i, j)*(7.0 / 255.0) + 0.5); // 3bits => max : 7
			g = floor(planes[1].at<uchar>(i, j)*(7.0 / 255.0) + 0.5); // 3bits => max : 7
			b = floor(planes[0].at<uchar>(i, j)*(3.0 / 255.0) + 0.5); // 2bits => max : 3
			temp = ((r  & RED_MASK) | (g << 3 & GREEN_MASK) | (b << 6 & BLUE_MASK)); //8bit RGB 332 data
			//push data in hexa decimal
			fprintf(f, "%02X,\n", temp);
		}
	}
#endif
	printf("\ndone\n");
	imshow("original", frame);


	fclose(f);
	waitKey();
	destroyAllWindows;
	return 0;
}


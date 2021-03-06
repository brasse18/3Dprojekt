#ifndef TIMEHANDLER_HPP
#define TIMEHANDLER_HPP

#include "GlobalResources.hpp"


class TimeHandler
{
public:
	TimeHandler();
	~TimeHandler();

	void TimeHandlerTimeFunction(); //RENAME
	void StartTimer();
	double GetTime();
	double GetFrameTime();
	void SetFrameCount(int newCount);

private:
	int FRAME_COUNT	= 0;
	double COUNTS_PER_SECOND = 0.0;
	__int64 COUNTER_START = 0;
	int FPS	= 0;
	__int64 FRAME_TIME_OLD = 0;
	//double FRAME_TIME; //never used ??

};


#endif // !TIMEHANDLER_HPP

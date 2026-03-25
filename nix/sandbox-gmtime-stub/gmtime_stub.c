/* ---------------------------------------------------------------------------
** This software is in the public domain, furnished "as is", without technical
** support, and with no warranty, express or implied, as to its usefulness for
** any purpose.
** -------------------------------------------------------------------------*/

#define _GNU_SOURCE
#include <time.h>
#include <string.h>

static struct tm constant_time = {
    .tm_sec   = 0,
    .tm_min   = 0,
    .tm_hour  = 0,
    .tm_mday  = 12,
    .tm_mon   = 3,
    .tm_year  = 120,
    .tm_wday  = 4,
    .tm_yday  = 72,
    .tm_isdst = 0
};

struct tm *gmtime(const time_t *timep) {
    return &constant_time;
}

struct tm *gmtime_r(const time_t *restrict timep, struct tm *restrict result) {
    memcpy(result, &constant_time, sizeof(struct tm));
    return result;
}

struct tm *localtime(const time_t *timep) {
    return &constant_time;
}

struct tm *localtime_r(const time_t *restrict timep, struct tm *restrict result) {
    memcpy(result, &constant_time, sizeof(struct tm));
    return result;
}

#include "calibration_lsi.h"

#include "CH58xBLE_LIB.h"
#include "ISP583.h"
#include "CH583SFR.h"

#define CAB_LSIFQ       32000

#define __IO                volatile  /*!< defines 'read / write' permissions   */

typedef struct __attribute__((packed))
{
    __IO uint32_t CTLR;
    __IO uint32_t SR;
    __IO uint64_t CNT;
    __IO uint64_t CMP;
} SysTick_Type;

#define SysTick                 ((SysTick_Type *)0xE000F000)

tmosTaskID halTaskID = INVALID_TASK_ID;

#define SysTick_LOAD_RELOAD_Msk    (0xFFFFFFFFFFFFFFFF)
#define SysTick_CTLR_INIT          (1 << 5)
#define SysTick_CTLR_MODE          (1 << 4)
#define SysTick_CTLR_STRE          (1 << 3)
#define SysTick_CTLR_STCLK         (1 << 2)
#define SysTick_CTLR_STIE          (1 << 1)
#define SysTick_CTLR_STE           (1 << 0)

#define SysTick_SR_CNTIF           (1 << 0)

typedef enum
{
    /* 校准精度越高，耗时越长 */
    Level_32 = 3, // 用时 1.2ms 1000ppm (32M 主频)  1100ppm (60M 主频)
    Level_64,     // 用时 2.2ms 800ppm  (32M 主频)  1000ppm (60M 主频)
    Level_128,    // 用时 4.2ms 600ppm  (32M 主频)  800ppm  (60M 主频)

} Cali_LevelTypeDef;

static inline uint32_t SysTick_Config(uint64_t ticks)
{
    if((ticks - 1) > SysTick_LOAD_RELOAD_Msk)
        return (1); /* Reload value impossible */

    SysTick->CMP = ticks - 1; /* set reload register */
    //PFIC_EnableIRQ(SysTick_IRQn);
    SysTick->CTLR = SysTick_CTLR_INIT |
                    SysTick_CTLR_STRE |
                    SysTick_CTLR_STCLK |
                    SysTick_CTLR_STIE |
                    SysTick_CTLR_STE; /* Enable SysTick IRQ and SysTick Timer */
    return (0);                       /* Function successful */
}

uint32_t SYS_GetSysTickCnt(void)
{
    uint32_t val;

    val = SysTick->CNT;
    return (val);
}

void sys_safe_access_enable() {
    *((volatile uint8_t*) 0x40001040) = 0x57;
    *((volatile uint8_t*) 0x40001040) = 0xA8;
}

void sys_safe_access_disable() {
    *((volatile uint8_t*) 0x40001040) = 0;
}

uint32_t RTC_GetCycle32k(void)
{
    volatile uint32_t i;

    do
    {
        i = R32_RTC_CNT_32K;
    } while(i != R32_RTC_CNT_32K);

    return (i);
}

uint32_t GetSysClock(void)
{
    uint16_t rev;

    rev = R16_CLK_SYS_CFG & 0xff;
    if((rev & 0x40) == (0 << 6))
    { // 32M进行分频
        return (32000000 / (rev & 0x1f));
    }
    else if((rev & RB_CLK_SYS_MOD) == (1 << 6))
    { // PLL进行分频
        return (480000000 / (rev & 0x1f));
    }
    else
    { // 32K做主频
        return (32000);
    }
}


void Calibration_LSI(Cali_LevelTypeDef cali_Lv)
{
    UINT32 i;
    INT32  cnt_offset;
    UINT8  retry = 0;
    INT32  freq_sys;
    UINT32 cnt_32k = 0;

    freq_sys = GetSysClock();

    sys_safe_access_enable();
    R8_CK32K_CONFIG |= RB_CLK_OSC32K_FILT;
    R8_CK32K_CONFIG &= ~RB_CLK_OSC32K_FILT;
    sys_safe_access_enable();
    R8_XT32K_TUNE &= ~3;
    R8_XT32K_TUNE |= 1;

    // 粗调
    sys_safe_access_enable();
    R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_TOTAL;
    R8_OSC_CAL_CTRL |= 1;

    while(1)
    {
        sys_safe_access_enable();
        R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
        R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
        R16_OSC_CAL_CNT |= RB_OSC_CAL_IF;
        while( (R8_OSC_CAL_CTRL & RB_OSC_CNT_EN) == 0 )
        {
            sys_safe_access_enable();
            R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
        }

        while(!(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT)); // 用于丢弃
        
        sys_safe_access_enable();
        R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_EN;
        R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
        R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
        R16_OSC_CAL_CNT |= RB_OSC_CAL_IF;
        while( (R8_OSC_CAL_CTRL & RB_OSC_CNT_EN) == 0 )
        {
            sys_safe_access_enable();
            R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
        }

        while(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT);
        cnt_32k = RTC_GetCycle32k();
        while(RTC_GetCycle32k() == cnt_32k);
        R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
        while(!(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT));
        i = R16_OSC_CAL_CNT; // 实时校准后采样值
        cnt_offset = (i & 0x3FFF) + R8_OSC_CAL_OV_CNT * 0x3FFF - 2000 * (freq_sys / 1000) / CAB_LSIFQ;
        if(((cnt_offset > -37 * (freq_sys / 1000) / CAB_LSIFQ) && (cnt_offset < 37 * (freq_sys / 1000) / CAB_LSIFQ)) || retry > 2)
        {
            if(retry)
                break;
        }
        retry++;
        cnt_offset = (cnt_offset > 0) ? (((cnt_offset * 2) / (74 * (freq_sys/1000) / 60000)) + 1) / 2 : (((cnt_offset * 2) / (74 * (freq_sys/1000) / 60000 )) - 1) / 2;
        sys_safe_access_enable();
        R16_INT32K_TUNE += cnt_offset;
    }

    // 细调
    // 配置细调参数后，丢弃2次捕获值（软件行为）上判断已有一次，这里只留一次
    sys_safe_access_enable();
    R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_TOTAL;
    R8_OSC_CAL_CTRL |= cali_Lv;
    while( (R8_OSC_CAL_CTRL & RB_OSC_CNT_TOTAL) != cali_Lv )
    {
        sys_safe_access_enable();
        R8_OSC_CAL_CTRL |= cali_Lv;
    }

    sys_safe_access_enable();
    R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_EN;
    R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
    R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
    R16_OSC_CAL_CNT |= RB_OSC_CAL_IF;
    while( (R8_OSC_CAL_CTRL & RB_OSC_CNT_EN) == 0 )
    {
        sys_safe_access_enable();
        R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
    }

    while(!(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT)); // 用于丢弃

    sys_safe_access_enable();
    R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_EN;
    R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
    R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
    R16_OSC_CAL_CNT |= RB_OSC_CAL_IF;
    while( (R8_OSC_CAL_CTRL & RB_OSC_CNT_EN) == 0 )
    {
        sys_safe_access_enable();
        R8_OSC_CAL_CTRL |= RB_OSC_CNT_EN;
    }

    while(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT);
    cnt_32k = RTC_GetCycle32k();
    while(RTC_GetCycle32k() == cnt_32k);
    R16_OSC_CAL_CNT |= RB_OSC_CAL_OV_CLR;
    while(!(R8_OSC_CAL_CTRL & RB_OSC_CNT_HALT));
    sys_safe_access_enable();
    R8_OSC_CAL_CTRL &= ~RB_OSC_CNT_EN;
    i = R16_OSC_CAL_CNT; // 实时校准后采样值

    cnt_offset = (i & 0x3FFF) + R8_OSC_CAL_OV_CNT * 0x3FFF -  4000 * (1 << cali_Lv) * (freq_sys / 1000000) / 256 * 1000/(CAB_LSIFQ/256);
    cnt_offset = (cnt_offset > 0) ? ((((cnt_offset * 2*(100 )) / (1366 * ((1 << cali_Lv)/8) * (freq_sys/1000) / 60000)) + 1) / 2)<<5 : ((((cnt_offset * 2*(100)) / (1366 * ((1 << cali_Lv)/8) * (freq_sys/1000) / 60000)) - 1) / 2)<<5;
    sys_safe_access_enable();
    R16_INT32K_TUNE += cnt_offset;
}

void Lib_Calibration_LSI(void)
{
  Calibration_LSI( Level_64 );
}

//====================================================================================================================================================//
#property copyright "Copyright 2014-2018, Nikolaos Pantzos"
#property link "https://www.mql5.com/en/users/pannik"
#property version "2.16"
#property description "This Expert Advisor is a tool to delete or put take profit, stop loss and manage it as basket orders or order by order."
#property description "\n- If select expert to manage 'Order_By_Order_All_Symbols' put it in one chart and expert manage all order of all symbols."
#property description "- If select expert to manage 'Same_Type_Of_Chart_Symbol_As_One' expert can to manage only orders as same chart symbol,"
#property description "- If you want to manage 'Same_Type_Of_Chart_Symbol_As_One' more of one symbols orders, attach expert in same charts/symbols of orders"
//#property icon        "\\Images\\TP-SL-TSL_Logo.ico";
#property strict
//========== define section ==============
#define NO_ERROR 1
#define AT_LEAST_ONE_FAILED 2
#define SLIPPAGE 3
//====================================================================================================================================================//
enum MO
{
    Order_By_Order_All_Symbols,
    Same_Type_Of_Chart_Symbol_As_One
};
enum SLHEDGEMODE
{
    Close_By_Order_Reach_Number,
    Close_By_Order_Break_Even
};
enum MAJORTREND
{
    Up_Trend,
    Down_Trend,
    All_Trend
};
//====================================================================================================================================================//
extern string SetManageOrders = "||=============== Manage Orders ===============||";

extern MO ManageOrders = Order_By_Order_All_Symbols;
extern SLHEDGEMODE ClosingHedgingOrders = Close_By_Order_Reach_Number;
extern MAJORTREND MajorCurrencyTrend = All_Trend;

extern string AddSLTP = "||=============== Add SL/TP ===============||";
extern bool PutTakeProfit = true;
extern double TakeProfitPips = 20.0;
extern bool PutStopLoss = true;
extern double StopLossPips = 20.0;
extern string TrailingSL = "||=============== Trailing SL ===============||";
extern bool UseTrailingStop = true;
extern double PutStopLossAfter = 0.0;
extern double TrailingStop = 5.0;
extern double TrailingStep = 1.0;
extern bool UseBreakEven = false;
extern double BreakEvenAfter = 10.0;
extern double BreakEvenPips = 5.0;
extern string DeleteSLTP = "||=============== Delete SL/TP ===============||";
extern bool DeleteTakeProfit = false;
extern bool DeleteStopLoss = false;
extern string AdvancedSets = "||=============== Advanced Sets ===============||";
extern string CommentOfOrder = "";
extern bool ModeDuplication = false;
extern bool DuplicateOnlyDD = false;
extern double DrawDownInPip = 18.0;
extern int DupMagik = 3411689;
extern int PipRecoverClose = 2;
extern double DDStopLossPips = 100.0;
extern double DDTakeProfitPips = 100.0;
extern double MySlippage = 3;
extern string MagicNumberInfo1 = ">0 = modify identifier orders";
extern string MagicNumberInfo2 = "0 = modify all orders";
extern string MagicNumberInfo3 = "-1 = modify only manual orders";
extern string MagicNumberInfo4 = "-2 = modify only chart symbol orders";
extern int MagicNumber = -2;
extern bool SoundAlert = true;
extern string ProtectorSets = "||=============== Protector Sets ===============||";
extern bool AdvancedProtector = false;
extern int MoneyRiskInPercent = 25;
extern int MaxMoneyValueToLose = 0;
extern bool CancelTradingLargeLot = false;
extern double LargeLotVal = 0.6;
extern int startTradeHH = 20;
extern int stopTradeHH = 2;
extern int tradeRepeatToStop = 3;
extern bool closeInitialFewTrade = true;
extern string masterAccNumb = "430719";

//====================================================================================================================================================//
string SoundModify = "tick.wav";
string BackgroundName;
string LargeLotOrderCommentToClose;

double StopLevel;
double AveragePriceBuy = 0;
double AveragePriceSell = 0;
double CurrentLoss = 0;
int SumOrders = 0;
int BuyOrders = 0;
int SellOrders = 0;
int MultiplierPoint;
int DigitsPrices;
bool MarketClosedCom;
bool CallMain = false;
long ChartColor;
string TP;
string SL;
string TSL;
string MN;
string SA;
string BE;
string ManageMode1 = "";
string ManageMode2 = "";
int TicketForDuplicateOrder = 0;
bool DuplicateOrderOpened = false;
bool IsMasterSignalStillTrade = false;
int numberOfDupOrderOpen = 0;
bool activateAdvancedMode = false;
double masterSignalLotSize = 0;
double dupOrderProfitLoss = 0;
double totalDuplicatePipProfit = 0;
double totalDupProfitUSD = 0;
datetime dupOpenTime = 0;
bool youAllowedToTrade = true;
int curSymbolOpenedCounter = 0;
bool reachToMaxRepeatTrade = false;
datetime hedgeOrderOpenTime = 0;
int ticketArr[];
int hedgeOrdersCnt = 0;

//====================================================================================================================================================//
//init function
int OnInit()
{
    //---------------------------------------------------------------------
    //Set timer
    EventSetMillisecondTimer(1000);
    //---------------------------------------------------------------------
    ArrayResize(ticketArr, 100, 100);

    ArrayInitialize(ticketArr, 0);
    hedgeOrdersCnt = 0;
    hedgeOrderOpenTime = 0;

    //Set background
    ChartColor = ChartGetInteger(0, CHART_COLOR_BACKGROUND, 0);
    BackgroundName = "Background-" + WindowExpertName();
    if (ObjectFind(BackgroundName) == -1)
        ChartBackground(BackgroundName, (color)ChartColor, 0, 15, 135, 179);
    //  CancelTradingLargeLot = false;
    activateAdvancedMode = false;

    //------------------------------------------------------
    //Broker 4 or 5 digits
    MultiplierPoint = 1;
    if ((MarketInfo(Symbol(), MODE_DIGITS) == 3) || (MarketInfo(Symbol(), MODE_DIGITS) == 5))
        MultiplierPoint = 10;
    //(MarketInfo(OrderSymbol(),MODE_POINT)*MultiplierPoint)
    //------------------------------------------------------
    //Minimum trailing, take profit, stop loss, break even
    StopLevel = MathMax(MarketInfo(Symbol(), MODE_FREEZELEVEL) / MultiplierPoint, MarketInfo(Symbol(), MODE_STOPLEVEL) / MultiplierPoint);
    if ((TrailingStop > 0) && (TrailingStop < StopLevel))
        TrailingStop = StopLevel;
    if (TrailingStep > TrailingStop)
        TrailingStep = TrailingStop;
    if ((TakeProfitPips > 0) && (TakeProfitPips < StopLevel))
        TakeProfitPips = StopLevel;
    if ((StopLossPips > 0) && (StopLossPips < StopLevel))
        StopLossPips = StopLevel;
    if (BreakEvenAfter < BreakEvenPips)
        BreakEvenAfter = BreakEvenPips;
    if (BreakEvenAfter - BreakEvenPips < StopLevel)
        BreakEvenAfter = BreakEvenPips + StopLevel;
    if ((PutStopLossAfter > 0) && (PutStopLossAfter < TrailingStop))
        PutStopLossAfter = TrailingStop;
    if (MagicNumber < -2)
        MagicNumber = -2;
    //------------------------------------------------------
    //External comment
    if (PutTakeProfit == true)
        TP = DoubleToStr(TakeProfitPips, 2);
    else
        TP = "FALSE";
    if (PutStopLoss == true)
        SL = DoubleToStr(StopLossPips, 2);
    else
        SL = "FALSE";
    if (UseTrailingStop == true)
        TSL = DoubleToStr(TrailingStop, 2) + "  (" + DoubleToStr(PutStopLossAfter, 2) + ")";
    else
        TSL = "FALSE";
    if (UseBreakEven == true)
        BE = DoubleToStr(BreakEvenPips, 2) + "  (" + DoubleToStr(BreakEvenAfter, 2) + ")";
    else
        BE = "FALSE";
    if (MagicNumber > 0)
        MN = DoubleToStr(MagicNumber, 0);
    if (MagicNumber == 0)
        MN = "All Orders";
    if (MagicNumber == -1)
        MN = "Manual Orders";
    if (MagicNumber == -2)
        MN = "Symbol Orders";
    if (SoundAlert == true)
        SA = "TRUE";
    else
        SA = "FALSE";
    //----------------------------------
    //Set manage mode
    if (ManageOrders == 0)
        ManageMode1 = "Order By Order";
    if (ManageOrders == 1)
        ManageMode1 = "Same Type As One";
    if ((ManageOrders == 0) && (MagicNumber != -2))
        ManageMode2 = " All Symbols";
    if ((ManageOrders == 0) && (MagicNumber == -2))
        ManageMode2 = " Chart Symbols";
    if (ManageOrders == 1)
        ManageMode2 = " " + Symbol() + " Symbol";
    //------------------------------------------------------
    if (!IsTesting())
        MainFunction(); //For show comment if market is closed
                        //------------------------------------------------------
    return (INIT_SUCCEEDED);
}
//====================================================================================================================================================//
//deinit function
void OnDeinit(const int reason)
{
    EventKillTimer();
    ObjectDelete(BackgroundName);
    Comment("");
}
//====================================================================================================================================================//
//start function
void OnTick()
{
    //---------------------------------------------------------------------
    //Reset values
    CallMain = true;
    //For testing
    //   if((IsTesting()) || (IsOptimization()) || (IsVisualMode()))
    //     {
    //      CallMain=false;
    //      MainFunction();
    //     }
    //---------------------------------------------------------------------
}
//====================================================================================================================================================//
void OnTimer()
{
    //---------------------------------------------------------------------
    //Call main function
    if ((youAllowedToTrade == true) && (reachToMaxRepeatTrade == false))
    {
        if ((CallMain == true) && (AdvancedProtector == false))
        {
            MainFunction();
        }
        else
        {

            if (AdvancedProtector == true)
            {

                MoneyManagement();
            }
        }
    }
    //---------------------------------------------------------------------
}

//+------------------------------------------------------------------+
int CloseAllThings()
{
    bool rv = NO_ERROR;
    int numOfOrders = OrdersTotal();
    int FirstOrderType = 0;

    for (int index = 0; index < OrdersTotal(); index++)
    {
        bool oS = OrderSelect(index, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol())
        {
            FirstOrderType = OrderType();
            break;
        }
    }

    for (int index = numOfOrders - 1; index >= 0; index--)
    {
        bool oS = OrderSelect(index, SELECT_BY_POS, MODE_TRADES);

        if (OrderSymbol() == Symbol())
            switch (OrderType())
            {
            case OP_BUY:
                if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), SLIPPAGE, Red))
                    rv = AT_LEAST_ONE_FAILED;
                break;

            case OP_SELL:
                if (!OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), SLIPPAGE, Red))
                    rv = AT_LEAST_ONE_FAILED;
                break;

            case OP_BUYLIMIT:
            case OP_SELLLIMIT:
            case OP_BUYSTOP:
            case OP_SELLSTOP:
                if (!OrderDelete(OrderTicket()))
                    rv = AT_LEAST_ONE_FAILED;
                break;
            }
    }

    return (rv);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void MoneyManagement()
{

    double TempLoss = 0;
    string mycomment = "";

    for (int j = 0; j < OrdersTotal(); j++)
    {
        if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
        {

            mycomment = OrderComment();

            if (StringFind(mycomment, CommentOfOrder, 0) != -1)
            {

                TempLoss = TempLoss + OrderProfit();
            }
        }
    }

    if (AccountBalance() > 0)
    {
        CurrentLoss = NormalizeDouble((TempLoss / AccountBalance()) * 100, 2);
    }

    if ((MoneyRiskInPercent > 0 && StrToInteger(DoubleToStr(MathAbs(CurrentLoss), 0)) > MoneyRiskInPercent) || (MaxMoneyValueToLose > 0 && StrToInteger(DoubleToStr(MathAbs(TempLoss), 0)) > MaxMoneyValueToLose))
    {
        //while(CloseAllThings()==AT_LEAST_ONE_FAILED)
        //{
        // Sleep(500);
        // Print("Order close failed - retrying error: #"+IntegerToString(GetLastError()));
        //}
        string onyComment = CommentOfOrder;

        while (CloseOpenOrders(onyComment) == 0)
        {
            Sleep(300);
        }
    }
}

int CloseOpenOrders(string specificComment)
{

    int TotalClose = 0; //We want to count how many orders have been closed

    double Slippage = MySlippage;

    //Normalization of the slippage
    if (Digits == 3 || Digits == 5)
    {
        Slippage = MySlippage * 10;
    }

    //We scan all the orders backwards, this is required as if we start from the first we will have problems with the counters and the loop
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {

        //We select the order of index i selecting by position and from the pool of market/pending trades
        //If the selection is successful we try to close it
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {

            //We define the close price, which depends on the type of order
            //We retrieve the price for the instrument of the order using MarketInfo(OrderSymbol(),MODE_BID) or MODE_ASK
            //And we normalize the price found
            if (StringFind(OrderComment(), specificComment, 0) != -1)
            {
                double ClosePrice = 0;

                // double Profit_in_pips = 0;

                RefreshRates();
                if (OrderType() == OP_BUY)
                {
                    ClosePrice = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_BID), Digits);
                    // Profit_in_pips = ( ClosePrice - OrderOpenPrice() ) / MarketInfo(OrderSymbol(),MODE_POINT) / MultiplierPoint;
                }
                if (OrderType() == OP_SELL)
                {
                    ClosePrice = NormalizeDouble(MarketInfo(OrderSymbol(), MODE_ASK), Digits);
                    // Profit_in_pips = ( OrderOpenPrice() - ClosePrice ) / MarketInfo(OrderSymbol(),MODE_POINT) / MultiplierPoint;
                }
                //If the order is closed correcly we increment the counter of closed orders
                //If the order fails to be closed we print the error
                if (OrderClose(OrderTicket(), OrderLots(), ClosePrice, Slippage, CLR_NONE))
                {
                    TotalClose++;

                    // totalDuplicatePipProfit += Profit_in_pips;   disable calculate the pip

                    totalDupProfitUSD += (OrderProfit() + OrderSwap() + OrderCommission());
                }
                else
                {
                    Print("Order failed to close with error - ", GetLastError());
                }
            }
        }
        //If the OrderSelect() fails we return the cause
        else
        {
            Print("Failed to select the order - ", GetLastError());
        }

        //We can have a delay if the execution is too fast, Sleep will wait x milliseconds before proceed with the code
        //Sleep(300);
    }
    //If the loop finishes it means there were no more open orders for that pair
    return (TotalClose);
}

void findLatestComment() // datetime orderopentime
{

    int ticket = -1;
    datetime close_time = dupOpenTime;
    // string CommentOfOrder = "56073";

    if (closeInitialFewTrade == true)
    {
        if (curSymbolOpenedCounter > 0)
        {

            for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
            {
                if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && (StringFind(OrderComment(), CommentOfOrder, 0) != -1) && OrderCloseTime() > hedgeOrderOpenTime)
                {
                    ticket = OrderTicket();
                    // close_time = OrderCloseTime();
                    // break;
                    curSymbolOpenedCounter = curSymbolOpenedCounter - 1;
                    if (curSymbolOpenedCounter < 0)
                    {
                        curSymbolOpenedCounter = 0;
                    }
                }
            }

            // in case that curSymbolOpenedCounter become zero
            if (curSymbolOpenedCounter == 0)
            {
                if (hedgeOrdersCnt > 0)
                {
                    while (CloseOpenOrders("hedge") == 0)
                    {
                        Sleep(200);
                    }

                    for (int i = 0; i < hedgeOrdersCnt; i++)
                    {
                        ticketArr[i] = 0;
                    }

                    hedgeOrderOpenTime = 0;
                    hedgeOrdersCnt = 0;
                }
            }
        }

        return;
        //tr
    }

    for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && (StringFind(OrderComment(), CommentOfOrder, 0) != -1) && OrderCloseTime() > close_time)
        {
            ticket = OrderTicket();
            close_time = OrderCloseTime();
            break;
        }
    }
    int ttClose = 0;
    double Profit_Pips = 0;
    bool status = OrderSelect(ticket, SELECT_BY_TICKET);
    if (status)
    {
        IsMasterSignalStillTrade = false;
        Print("The latest Maximus close price is ");
        // Print("profit is ", OrderProfit());
        if (OrderType() == OP_BUY)
        {

            Profit_Pips = (OrderClosePrice() - OrderOpenPrice()) / MarketInfo(OrderSymbol(), MODE_POINT) / MultiplierPoint;
        }

        if (OrderType() == OP_SELL)
        {
            Profit_Pips = (OrderOpenPrice() - OrderClosePrice()) / MarketInfo(OrderSymbol(), MODE_POINT) / MultiplierPoint;
        }

        // totalDuplicatePipProfit += Profit_Pips;

        Print("profit in pips is ", Profit_Pips);

        // SendMail("The master signal is close");

        totalDupProfitUSD += (OrderProfit() + OrderSwap() + OrderCommission());

        //     SendMail("Maximus just close", "Consider close the Maximus");
        //     Close the duplicate order too
        ttClose = CloseOpenOrders("dongcp");
        if (ttClose > 0)
        {
            DuplicateOrderOpened = false;
            numberOfDupOrderOpen = numberOfDupOrderOpen - 1;

            //numberOfDupOrderOpen is to indicate the total order open by duplication
        }
    }

    //if(activateAdvancedMode==false)
    //{
    // Check if the master signal is not closed but the duplicate order is closed or not
    if ((IsMasterSignalStillTrade == true) && (DuplicateOrderOpened == true))
    {
        close_time = dupOpenTime;
        ticket = -1;

        for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && (StringFind(OrderComment(), "dongcp", 0) != -1) && OrderCloseTime() > close_time)
            {
                ticket = OrderTicket();
                close_time = OrderCloseTime();
                break;
            }
        }
        if (OrderSelect(ticket, SELECT_BY_TICKET))
        {
            if (OrderProfit() >= 0)
            {
                Print("Close with profit");
                // dupOrderProfitLoss=TakeProfitPips;
            }
            else
            {
                Print("Close with lost");
                // dupOrderProfitLoss=StopLossPips * -1;
            }

            //  totalDuplicatePipProfit += dupOrderProfitLoss;

            totalDupProfitUSD += (OrderProfit() + OrderSwap() + OrderCommission());

            numberOfDupOrderOpen = numberOfDupOrderOpen - 1;

            DuplicateOrderOpened = false;
        }
    }
    // }
    // && (magic_number==0 || OrderMagicNumber() == magic_number)
    if (activateAdvancedMode == true)
    {
        ticket = -1;
        close_time = dupOpenTime;

        for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && (StringFind(OrderComment(), "dongadv", 0) != -1) && OrderCloseTime() > close_time)
            {
                ticket = OrderTicket();
                close_time = OrderCloseTime();
                break;
            }
        }
        if (OrderSelect(ticket, SELECT_BY_TICKET))
        {
            // we will not calculate profit or loss here
            activateAdvancedMode = false;
            numberOfDupOrderOpen = numberOfDupOrderOpen - 1;
            totalDuplicatePipProfit = 0;
            totalDupProfitUSD = 0;
            // totalDupProfitUSD what is this for kub

            if (numberOfDupOrderOpen < 0)
            {
                numberOfDupOrderOpen = 0;
            }
        }
    }
}

bool modifyStopLossToBE(int ticketOfOrder)
{
    double localSL = 0;
    double priceBB = 0;
    double priceSA = 0;

    if (ticketOfOrder != 0)
    {
        if (OrderSelect(ticketOfOrder, SELECT_BY_TICKET))
        {
            if (OrderStopLoss() == 0)
            {
                // been not modified the stoploss yet
                if (BreakEvenPips > 0)
                {

                    if (OrderType() == OP_BUY)
                    {
                        priceBB = MarketInfo(OrderSymbol(), MODE_BID);

                        //Break even
                        if (
                            (NormalizeDouble(priceBB - BreakEvenAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) >= OrderOpenPrice()) &&
                            ((NormalizeDouble(OrderOpenPrice() + BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) > OrderStopLoss()) || (OrderStopLoss() == 0)))
                            localSL = NormalizeDouble(OrderOpenPrice() + BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        //-----------------------
                    }
                    else
                    {

                        priceSA = MarketInfo(OrderSymbol(), MODE_ASK);

                        //Break even
                        if (
                            (NormalizeDouble(priceSA + BreakEvenAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) <= OrderOpenPrice()) &&
                            ((NormalizeDouble(OrderOpenPrice() - BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) < OrderStopLoss()) || (OrderStopLoss() == 0)))
                            localSL = NormalizeDouble(OrderOpenPrice() - BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        //-----------------------
                        //Modify
                    }

                    if (localSL > 0)
                    {
                        /* code */
                        bool isOrderModify = false;
                        isOrderModify = OrderModify(OrderTicket(), OrderOpenPrice(), localSL, 0, 0, clrBlue);
                        if (isOrderModify == true)
                        {
                            Print("Modify hedge order ticket");
                        }

                        return isOrderModify;
                    }
                }
            }
        }
    }

    return false;
}
//====================================================================================================================================================//
//main function
void MainFunction()
{
    MarketClosedCom = false;
    double LocalTakeProfit = 0;
    double LocalStopLoss = 0;
    bool WasOrderModified = false;
    double PriceBuyAsk = 0;
    double PriceBuyBid = 0;
    double PriceSellAsk = 0;
    double PriceSellBid = 0;
    double Spread = 0;
    string comment = "";
    double localTotalPipInDDMode = 0;
    double martingleLotInDDMode = 0;
    //----------------------------------
    //expert not enabled
    if ((!IsExpertEnabled()) && (!IsTesting()))
    {
        Comment("==================",
                "\n\n    ", WindowExpertName(),
                "\n\n==================",
                "\n\n    Expert Not Enabled ! ! !",
                "\n\n    Please Turn On Expert",
                "\n\n\n\n==================");
        return;
    }
    //------------------------------------------------------
    //Comment in screen
    Comment("==================",
            "\n  ", WindowExpertName(),
            "\n  Ready To Modify Orders",
            "\n==================",
            "\n  Comment of Order: ", CommentOfOrder,
            "\n  Manage: ", ManageMode1,
            "\n  Symbol: ", ManageMode2,
            "\n==================",
            "\n  Take Profit  : ", TP,
            "\n  Stop Loss    : ", SL,
            "\n  Trailing SL   : ", TSL,
            "\n  Break Even : ", BE,
            "\n==================",
            "\n  Orders ID   : ", MN,
            "\n  Sound Alert : ", SA,
            "\n==================");
    //------------------------------------------------------
    //Reset switchs
    if (DeleteTakeProfit == true)
        PutTakeProfit = false;
    if (DeleteStopLoss == true)
    {
        PutStopLoss = false;
        UseTrailingStop = false;
        UseBreakEven = false;
    }
    //------------------------------------------------------
    //Count orders
    if (ManageOrders == 1) //basket
    {
        CountOrders();
        Spread = (Ask - Bid) / (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint);
        if (AveragePriceBuy != 0)
        {
            PriceBuyAsk = AveragePriceBuy;
            PriceBuyBid = AveragePriceBuy - Spread;
        }
        else
        {
            PriceBuyAsk = Ask;
            PriceBuyBid = Bid;
        }
        //---
        if (AveragePriceSell != 0)
        {
            PriceSellAsk = AveragePriceSell + Spread;
            PriceSellBid = AveragePriceSell;
        }
        else
        {
            PriceSellAsk = Ask;
            PriceSellBid = Bid;
        }
        if (activateAdvancedMode == false)
        {
            if ((DuplicateOrderOpened == false) && (IsMasterSignalStillTrade == false))
            {
                dupOpenTime = 0;

                if ((curSymbolOpenedCounter > 0) && (closeInitialFewTrade == true))
                {
                    Print("I am here na krub");
                    findLatestComment();
                }
            }
            else
            {
                if (dupOpenTime > 0)
                {
                    findLatestComment();
                }
            }
        }
        else
        {
            // In vase that in advanced mode we still need to check the trade of master signal
            if (dupOpenTime > 0)
            {
                findLatestComment();
            }
        }
    }
    //------------------------------------------------------
    //Select order
    LargeLotOrderCommentToClose = "none";

    for (int i = 0; i < OrdersTotal(); i++)
    {

        if ((DuplicateOrderOpened == true) && (ModeDuplication == true) && (DuplicateOnlyDD == false))
        {
            break;
        }

        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true)
        {
            comment = OrderComment();

            if (StringFind(comment, CommentOfOrder, 0) == -1)
            {
                continue;
            }

            if (activateAdvancedMode == true)
            {
                // Do something here
                // need to check about the profit pip of duplicate comment dongcp too
                // This piece of code have a big bug you need to modify it immediately krub

                if ((StringFind(comment, "dongcp", 0) != -1) || (StringFind(comment, "dongadv", 0) != -1) || ((StringFind(comment, CommentOfOrder, 0) != -1) && (IsMasterSignalStillTrade == true)))
                {
                    double dongAdvOpenPrice = 0;
                    double diff_p = 0;

                    if (OrderType() == OP_BUY)
                    {
                        dongAdvOpenPrice = OrderOpenPrice();
                        diff_p = (NormalizeDouble(((Ask - dongAdvOpenPrice) / MarketInfo(Symbol(), MODE_POINT)), (int)MarketInfo(Symbol(), MODE_DIGITS))) / MultiplierPoint; //point_compat;
                        //diff=diff+DiffPips;
                        //totalDuplicatePipProfit = totalDuplicatePipProfit + diff_p;
                        localTotalPipInDDMode = localTotalPipInDDMode + ((diff_p * OrderLots() * MultiplierPoint) + OrderSwap() + OrderCommission());
                        // 10 * 1.00 * 10
                    }

                    if (OrderType() == OP_SELL)
                    {
                        dongAdvOpenPrice = OrderOpenPrice();
                        diff_p = (NormalizeDouble(((dongAdvOpenPrice - Bid) / MarketInfo(Symbol(), MODE_POINT)), (int)MarketInfo(Symbol(), MODE_DIGITS))) / MultiplierPoint; //point_compat;
                        //diff=diff+DiffPips;
                        //totalDuplicatePipProfit = totalDuplicatePipProfit + diff_p;
                        localTotalPipInDDMode = localTotalPipInDDMode + ((diff_p * OrderLots() * MultiplierPoint) + OrderSwap() + OrderCommission());
                    }
                }
                continue;
            }
            if ((((OrderMagicNumber() == MagicNumber) || (MagicNumber == 0)) || ((OrderMagicNumber() == 0) && (MagicNumber == -1)) || ((OrderSymbol() == Symbol()) && (MagicNumber == -2))) && ((OrderSymbol() == Symbol()) || (ManageOrders == 0)))
            {
                DigitsPrices = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
                //------------------------------------------------------
                //Set prices
                if (ManageOrders == 0)
                {
                    PriceBuyAsk = MarketInfo(OrderSymbol(), MODE_ASK);
                    PriceBuyBid = MarketInfo(OrderSymbol(), MODE_BID);
                    PriceSellAsk = MarketInfo(OrderSymbol(), MODE_ASK);
                    PriceSellBid = MarketInfo(OrderSymbol(), MODE_BID);
                }
                //------------------------------------------------------
                //Delete stoploss and/or take profit
                if ((DeleteTakeProfit == true) || (DeleteStopLoss == true))
                {
                    LocalStopLoss = 0;
                    LocalTakeProfit = 0;
                    if (DeleteStopLoss == true)
                        LocalStopLoss = -1;
                    if (DeleteTakeProfit == true)
                        LocalTakeProfit = -1;
                    if ((DeleteStopLoss == true) && (OrderStopLoss() != 0))
                        LocalStopLoss = 0;
                    if ((DeleteStopLoss == false) && (OrderStopLoss() != 0))
                        LocalStopLoss = OrderStopLoss();
                    if ((DeleteTakeProfit == true) && (OrderTakeProfit() != 0))
                        LocalTakeProfit = 0;
                    if ((DeleteTakeProfit == false) && (OrderTakeProfit() != 0))
                        LocalTakeProfit = OrderTakeProfit();
                    //---
                    if ((LocalStopLoss == 0) || (LocalTakeProfit == 0))
                        WasOrderModified = OrderModify(OrderTicket(), OrderOpenPrice(), LocalStopLoss, LocalTakeProfit, 0, clrNONE);
                    if (WasOrderModified > 0)
                    {
                        Print("Modify ticket: " + DoubleToStr(OrderTicket(), 0));
                        if (SoundAlert == true)
                            PlaySound(SoundModify);
                        continue;
                    }
                }
                //------------------------------------------------------
                //Check stop loss and take profit
                if ((UseBreakEven == false) && (UseTrailingStop == false))
                {
                    if ((ModeDuplication == true) && (DuplicateOrderOpened == true))
                        continue;
                    // The old one below
                    if ((PutStopLoss == true) && (OrderStopLoss() != 0) && (PutTakeProfit == true) && (OrderTakeProfit() != 0))
                        continue;
                    if ((PutStopLoss == true) && (OrderStopLoss() != 0) && (PutTakeProfit == false))
                        continue;
                    if ((PutStopLoss == false) && (PutTakeProfit == true) && (OrderTakeProfit() != 0))
                        continue;
                }
                //------------------------------------------------------
                //Modify buy
                curSymbolOpenedCounter = curSymbolOpenedCounter + 1;

                if (OrderType() == OP_BUY)
                {
                    LocalStopLoss = 0;
                    LocalTakeProfit = 0;
                    WasOrderModified = false;
                    //------------------------------------------------------
                    //Put stoploss and/or take profit
                    if (ManageOrders == 0)
                    {
                        if ((PutStopLoss == true) && (OrderStopLoss() == 0))
                            LocalStopLoss = NormalizeDouble(PriceBuyBid - StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        if ((PutTakeProfit == true) && (OrderTakeProfit() == 0))
                            LocalTakeProfit = NormalizeDouble(PriceBuyAsk + TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        else
                            LocalTakeProfit = OrderTakeProfit();
                    }
                    //---
                    if (ManageOrders == 1)
                    {
                        if (StringFind(comment, CommentOfOrder, 0) != -1)
                        {
                            if ((PutStopLoss == true) && ((OrderStopLoss() == 0) || (OrderStopLoss() != NormalizeDouble(PriceBuyBid - StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices))))
                                LocalStopLoss = NormalizeDouble(PriceBuyBid - StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                            if ((PutTakeProfit == true) && ((OrderTakeProfit() == 0) || (OrderTakeProfit() != NormalizeDouble(PriceBuyAsk + TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices))))
                                LocalTakeProfit = NormalizeDouble(PriceBuyAsk + TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                            else
                                LocalTakeProfit = OrderTakeProfit();

                            if ((activateAdvancedMode == false) && (DuplicateOnlyDD == true) && (ModeDuplication == true) && (IsMasterSignalStillTrade == true))
                            {
                                int point_compat = 1;
                                if (Digits == 3 || Digits == 5)
                                    point_compat = 10;

                                double diff1 = OrderOpenPrice();
                                double DiffPips = (NormalizeDouble(((Ask - diff1) / MarketInfo(Symbol(), MODE_POINT)), (int)MarketInfo(Symbol(), MODE_DIGITS))) / point_compat;
                                if (DiffPips > (DrawDownInPip * -1))
                                {
                                    LocalStopLoss = 0;
                                    LocalTakeProfit = 0;
                                }
                                else
                                {
                                    // recalculate the LocalStopLoss and LocalTakeProfit
                                    activateAdvancedMode = true;
                                    masterSignalLotSize = OrderLots();

                                    if (PutStopLoss == true)
                                    {
                                        LocalStopLoss = NormalizeDouble(Bid - DDStopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                                    }
                                    if (PutTakeProfit == true)
                                    {
                                        LocalTakeProfit = NormalizeDouble(Ask + DDTakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);

                                        //  else LocalTakeProfit=OrderTakeProfit();
                                    }
                                }
                            }
                            // Need to handle the closer here
                        }
                    }
                    //------------------------------------------------------
                    //Trailing stop
                    if (((UseTrailingStop == true) && (LocalStopLoss == 0) && (TrailingStop > 0)) &&
                        ((PutStopLossAfter == 0) || (NormalizeDouble(PriceBuyBid - PutStopLossAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) >= OrderOpenPrice())) &&
                        (NormalizeDouble(PriceBuyBid - ((TrailingStop + TrailingStep) * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint)), DigitsPrices) > OrderStopLoss()))
                        LocalStopLoss = NormalizeDouble(PriceBuyBid - TrailingStop * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                    //------------------------------------------------------
                    //Break even
                    if ((UseBreakEven == true) && (LocalStopLoss == 0) && (BreakEvenPips > 0) &&
                        (NormalizeDouble(PriceBuyBid - BreakEvenAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) >= OrderOpenPrice()) &&
                        ((NormalizeDouble(OrderOpenPrice() + BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) > OrderStopLoss()) || (OrderStopLoss() == 0)))
                        LocalStopLoss = NormalizeDouble(OrderOpenPrice() + BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                    //-----------------------
                    //Modify
                    if (((LocalStopLoss > 0) && (LocalStopLoss != NormalizeDouble(OrderStopLoss(), DigitsPrices)) && (OrderStopLoss() != 0)) || (((LocalStopLoss > 0) && (OrderStopLoss() == 0)) || ((LocalTakeProfit > 0) && (OrderTakeProfit() == 0))))
                    {
                        // Not Modify but open new order instead
                        if (ModeDuplication == false)
                        {
                            WasOrderModified = OrderModify(OrderTicket(), OrderOpenPrice(), LocalStopLoss, LocalTakeProfit, 0, clrBlue);

                            // Or Need to handle the closer here
                            // After the loser then continue only
                            if ((CancelTradingLargeLot == true) && (curSymbolOpenedCounter >= tradeRepeatToStop))
                            {
                                if (OrderLots() > LargeLotVal)
                                {
                                    LargeLotOrderCommentToClose = comment;
                                    reachToMaxRepeatTrade = true;

                                    Print("Found the large lot size!!!");
                                    break;
                                }
                            }
                            else
                            {
                                // Close the order immediately
                                if ((closeInitialFewTrade == true) && (curSymbolOpenedCounter < tradeRepeatToStop))
                                {
                                    // (OrderLots() < 0.03)
                                    // Open the hedge trade
                                    if (true)
                                    {

                                        // This is the hedge mode (will implement later)
                                        int temp = OrderTicket();
                                        bool isOrderAlreadyExistInArr = false;
                                        string hitDDorderComment = comment; // OrderComment();

                                        for (int qqq = 0; qqq < hedgeOrdersCnt; qqq++)
                                        {
                                            if ((ticketArr[qqq] == temp) && (ticketArr[qqq] != 0))
                                            {
                                                isOrderAlreadyExistInArr = true;
                                                break;
                                            }
                                        }

                                        if (isOrderAlreadyExistInArr == false)
                                        {
                                            bool canOpenHedgeOrd = false;
                                            int ticketNumb = -1;
                                            int replaced = StringReplace(hitDDorderComment, masterAccNumb, "hedge");

                                            if (hedgeOrdersCnt == 0)
                                            {
                                                //if(hedgeOrderOpenTime < 1)
                                                //{
                                                hedgeOrderOpenTime = OrderOpenTime();
                                                //}
                                            }

                                            if (replaced == 1)
                                            {
                                                if (OrderType() == OP_BUY)
                                                {
                                                    // Open the hedging for buy (sell order)
                                                    // TicketForDuplicateOrder=

                                                    ticketNumb = OrderSend(OrderSymbol(), OP_SELL, OrderLots(), Bid, 3, 0.0, 0.0, hitDDorderComment, DupMagik, 0, clrBrown);
                                                    if (ticketNumb > 0)
                                                    {
                                                        canOpenHedgeOrd = true;
                                                    }
                                                }
                                                //else if(OrderType()==OP_SELL)
                                                //{
                                                // Open the hedging for sell (but order)
                                                // TicketForDuplicateOrder=

                                                //ticketNumb = OrderSend(OrderSymbol(),OP_BUY,OrderLots(),Ask,3,0.0,0.0,hitDDorderComment,DupMagik,0,clrBrown);
                                                //if(ticketNumb > 0)
                                                //{
                                                //   canOpenHedgeOrd = true;
                                                //}
                                                //}
                                            }

                                            if (canOpenHedgeOrd == true)
                                            {
                                                ticketArr[hedgeOrdersCnt] = ticketNumb; // TicketForDuplicateOrder;
                                                hedgeOrdersCnt = hedgeOrdersCnt + 1;
                                            }
                                        }
                                    }
                                    // {

                                    // }
                                }
                                else
                                {
                                    if ((closeInitialFewTrade == true) && (curSymbolOpenedCounter >= tradeRepeatToStop))
                                    {
                                        // Here we need to close all hedging order
                                        // (OrderLots() > 0.03)
                                        // Just use part of comment
                                        // First we need to clear the ticketArr array first
                                        // Second we need to reset the hedgeOrdersCnt to become zero

                                        if (ClosingHedgingOrders == 0)
                                        {
                                            while (CloseOpenOrders("hedge") == 0)
                                            {
                                                Sleep(200);
                                            }

                                            for (int ik = 0; ik < hedgeOrdersCnt; ik++)
                                            {
                                                ticketArr[ik] = 0;
                                            }

                                            hedgeOrderOpenTime = 0;
                                            hedgeOrdersCnt = 0;
                                        }
                                        else
                                        {
                                            // Modify the hedging order to have the sloploss at breakeven
                                            bool someAreTrue = false;

                                            for (int j = 0; j < hedgeOrdersCnt; j++)
                                            {
                                                /* code */
                                                bool rr;
                                                int tikOrder = ticketArr[j];

                                                rr = modifyStopLossToBE(tikOrder);
                                                if (rr == true)
                                                {
                                                    someAreTrue = true;
                                                }
                                            }
                                            if (someAreTrue == true)
                                            {
                                                continue;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        else
                        {
                            if (IsMasterSignalStillTrade == false)
                            {

                                dupOpenTime = OrderOpenTime();
                                TicketForDuplicateOrder = OrderSend(OrderSymbol(), OP_BUY, OrderLots(), Ask, 3, LocalStopLoss, LocalTakeProfit, "dongcp", DupMagik, 0, clrLawnGreen);
                                if (TicketForDuplicateOrder > 0)
                                {
                                    Print("reopened");
                                    DuplicateOrderOpened = true;
                                    IsMasterSignalStillTrade = true;
                                    numberOfDupOrderOpen += 1;
                                }
                                else
                                {
                                    Print("duplicate failed ", GetLastError());
                                    SendMail("Duplicate fail", "Please fix immediately");
                                }
                            }
                        }
                    }
                    if ((activateAdvancedMode == true) && (IsMasterSignalStillTrade == true))
                    {
                        // Open order with lot multiply by 3
                        // This is critical level only
                        if ((LocalStopLoss > 0) && (LocalTakeProfit > 0))
                        {
                            if (masterSignalLotSize > 0)
                            {
                                int ttt = OrderSend(OrderSymbol(), OP_BUY, masterSignalLotSize * 3, Ask, 3, LocalStopLoss, LocalTakeProfit, "dongadv", DupMagik, 0, clrWhite);
                                if (ttt > 0)
                                {
                                    numberOfDupOrderOpen += 1;
                                }
                                else
                                {
                                    SendMail("Advance dup fail", "Please fix it krub");
                                }
                            }
                        }
                    }
                    if ((WasOrderModified > 0) && (ModeDuplication == false))
                    {
                        Print("Modify buy ticket: " + DoubleToStr(OrderTicket(), 0));
                        if (SoundAlert == true)
                            PlaySound(SoundModify);
                    }
                } //End if(OrderType()
                //------------------------------------------------------
                //Modify sell
                if (OrderType() == OP_SELL)
                {
                    LocalStopLoss = 0;
                    LocalTakeProfit = 0;
                    WasOrderModified = false;
                    //------------------------------------------------------
                    //Put stoploss and/or take profit
                    if (ManageOrders == 0)
                    {
                        if ((PutStopLoss == true) && (OrderStopLoss() == 0))
                            LocalStopLoss = NormalizeDouble(PriceSellAsk + StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        if ((PutTakeProfit == true) && (OrderTakeProfit() == 0))
                            LocalTakeProfit = NormalizeDouble(PriceSellBid - TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                        else
                            LocalTakeProfit = OrderTakeProfit();
                    }
                    //---
                    if (ManageOrders == 1)
                    {
                        if (StringFind(comment, CommentOfOrder, 0) != -1)
                        {
                            if ((PutStopLoss == true) && ((OrderStopLoss() == 0) || (OrderStopLoss() != NormalizeDouble(PriceSellAsk + StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices))))
                                LocalStopLoss = NormalizeDouble(PriceSellAsk + StopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                            if ((PutTakeProfit == true) && ((OrderTakeProfit() == 0) || (OrderTakeProfit() != NormalizeDouble(PriceSellBid - TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices))))
                                LocalTakeProfit = NormalizeDouble(PriceSellBid - TakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                            else
                                LocalTakeProfit = OrderTakeProfit();

                            if ((activateAdvancedMode == false) && (DuplicateOnlyDD == true) && (ModeDuplication == true) && (IsMasterSignalStillTrade == true))
                            {
                                int point_compat = 1;
                                if (Digits == 3 || Digits == 5)
                                    point_compat = 10;

                                double diff1 = OrderOpenPrice();
                                double DiffPips = (NormalizeDouble(((diff1 - Bid) / MarketInfo(Symbol(), MODE_POINT)), (int)MarketInfo(Symbol(), MODE_DIGITS))) / point_compat;
                                if (DiffPips > (DrawDownInPip * -1))
                                {
                                    LocalStopLoss = 0;
                                    LocalTakeProfit = 0;
                                }
                                else
                                {
                                    // recalculate the LocalStopLoss and LocalTakeProfit
                                    activateAdvancedMode = true;
                                    masterSignalLotSize = OrderLots();

                                    if (PutStopLoss == true)
                                    {
                                        LocalStopLoss = NormalizeDouble(Ask + DDStopLossPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                                    }
                                    if (PutTakeProfit == true)
                                    {
                                        LocalTakeProfit = NormalizeDouble(Bid - DDTakeProfitPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);

                                        //  else LocalTakeProfit=OrderTakeProfit();
                                    }
                                }
                            }
                        }
                    }
                    //------------------------------------------------------
                    //Trailing stop
                    if (((UseTrailingStop == true) && (LocalStopLoss == 0) && (TrailingStop > 0)) &&
                        ((PutStopLossAfter == 0) || (NormalizeDouble(PriceSellAsk + PutStopLossAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) <= OrderOpenPrice())) &&
                        (NormalizeDouble(PriceSellAsk + ((TrailingStop + TrailingStep) * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint)), DigitsPrices) < OrderStopLoss()))
                        LocalStopLoss = NormalizeDouble(PriceSellAsk + TrailingStop * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                    //------------------------------------------------------
                    //Break even
                    if ((UseBreakEven == true) && (LocalStopLoss == 0) && (BreakEvenPips > 0) &&
                        (NormalizeDouble(PriceSellAsk + BreakEvenAfter * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) <= OrderOpenPrice()) &&
                        ((NormalizeDouble(OrderOpenPrice() - BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices) < OrderStopLoss()) || (OrderStopLoss() == 0)))
                        LocalStopLoss = NormalizeDouble(OrderOpenPrice() - BreakEvenPips * (MarketInfo(OrderSymbol(), MODE_POINT) * MultiplierPoint), DigitsPrices);
                    //-----------------------
                    //Modify
                    if (((LocalStopLoss > 0) && (LocalStopLoss != NormalizeDouble(OrderStopLoss(), DigitsPrices)) && (OrderStopLoss() != 0)) || (((LocalStopLoss > 0) && (OrderStopLoss() == 0)) || ((LocalTakeProfit > 0) && (OrderTakeProfit() == 0))))
                    {
                        // Not Modify but open new order instead

                        if (ModeDuplication == false)
                        {
                            // WasOrderModified=OrderModify(OrderTicket(),OrderOpenPrice(),LocalStopLoss,LocalTakeProfit,0,clrRed);
                            WasOrderModified = OrderModify(OrderTicket(), OrderOpenPrice(), LocalStopLoss, LocalTakeProfit, 0, clrBlue);

                            // Or Need to handle the closer here
                            // After the loser then continue only
                            if ((CancelTradingLargeLot == true) && (curSymbolOpenedCounter >= tradeRepeatToStop))
                            {
                                if (OrderLots() > LargeLotVal)
                                {
                                    LargeLotOrderCommentToClose = comment;
                                    reachToMaxRepeatTrade = true;

                                    Print("Found the large lot size!!!");
                                    break;
                                }
                            }
                            else
                            {
                                // Close the order immediately
                                if ((closeInitialFewTrade == true) && (curSymbolOpenedCounter < tradeRepeatToStop))
                                {
                                    // (OrderLots() < 0.03)
                                    // Open the hedge trade
                                    if (true)
                                    {

                                        // This is the hedge mode (will implement later)
                                        int temp = OrderTicket();
                                        bool isOrderAlreadyExistInArr = false;
                                        string hitDDorderComment = comment; // OrderComment();

                                        for (int qqq = 0; qqq < hedgeOrdersCnt; qqq++)
                                        {
                                            if ((ticketArr[qqq] == temp) && (ticketArr[qqq] != 0))
                                            {
                                                isOrderAlreadyExistInArr = true;
                                                break;
                                            }
                                        }

                                        if (isOrderAlreadyExistInArr == false)
                                        {
                                            bool canOpenHedgeOrd = false;
                                            int ticketNumb = -1;
                                            int replaced = StringReplace(hitDDorderComment, masterAccNumb, "hedge");

                                            if (hedgeOrdersCnt == 0)
                                            {
                                                //if(hedgeOrderOpenTime < 1)
                                                //{
                                                hedgeOrderOpenTime = OrderOpenTime();
                                                //}
                                            }

                                            if (replaced == 1)
                                            {
                                                //if (OrderType() == OP_BUY)
                                                //{
                                                // Open the hedging for buy (sell order)
                                                // TicketForDuplicateOrder=

                                                //    ticketNumb = OrderSend(OrderSymbol(), OP_SELL, OrderLots(), Bid, 3, 0.0, 0.0, hitDDorderComment, DupMagik, 0, clrBrown);
                                                //    if (ticketNumb > 0)
                                                //    {
                                                //        canOpenHedgeOrd = true;
                                                //    }
                                                //}
                                                if (OrderType() == OP_SELL)
                                                {
                                                    // Open the hedging for sell (but order)
                                                    // TicketForDuplicateOrder=

                                                    ticketNumb = OrderSend(OrderSymbol(), OP_BUY, OrderLots(), Ask, 3, 0.0, 0.0, hitDDorderComment, DupMagik, 0, clrBrown);
                                                    if (ticketNumb > 0)
                                                    {
                                                        canOpenHedgeOrd = true;
                                                    }
                                                }
                                            }

                                            if (canOpenHedgeOrd == true)
                                            {
                                                ticketArr[hedgeOrdersCnt] = ticketNumb; // TicketForDuplicateOrder;
                                                hedgeOrdersCnt = hedgeOrdersCnt + 1;
                                            }
                                        }
                                    }
                                    // {

                                    // }
                                }
                                else
                                {
                                    if ((closeInitialFewTrade == true) && (curSymbolOpenedCounter >= tradeRepeatToStop))
                                    {
                                        // Here we need to close all hedging order
                                        // (OrderLots() > 0.03)
                                        // Just use part of comment
                                        // First we need to clear the ticketArr array first
                                        // Second we need to reset the hedgeOrdersCnt to become zero
                                        if (ClosingHedgingOrders == 0)
                                        {
                                            while (CloseOpenOrders("hedge") == 0)
                                            {
                                                Sleep(200);
                                            }

                                            for (int ik = 0; ik < hedgeOrdersCnt; ik++)
                                            {
                                                ticketArr[ik] = 0;
                                            }

                                            hedgeOrderOpenTime = 0;
                                            hedgeOrdersCnt = 0;
                                        }
                                        else
                                        {
                                            // Modify the hedging order to have the sloploss at breakeven
                                            bool someAreTrue = false;

                                            for (int j = 0; j < hedgeOrdersCnt; j++)
                                            {
                                                /* code */
                                                bool rr;
                                                int tikOrder = ticketArr[j];

                                                rr = modifyStopLossToBE(tikOrder);
                                                if (rr == true)
                                                {
                                                    someAreTrue = true;
                                                }
                                            }
                                            if (someAreTrue == true)
                                            {
                                                continue;
                                            }
                                        }
                                    }
                                }
                            }

                            //if ((CancelTradingLargeLot == true) && (curSymbolOpenedCounter >= tradeRepeatToStop))
                            //{
                            //    if (OrderLots() > LargeLotVal)
                            //    {
                            //        LargeLotOrderCommentToClose = comment;
                            //       reachToMaxRepeatTrade = true;

                            //       Print("Found the large lot size!!!");
                            //       break;
                            //   }
                            //}
                        }
                        else
                        {
                            if (IsMasterSignalStillTrade == false)
                            {

                                dupOpenTime = OrderOpenTime();
                                TicketForDuplicateOrder = OrderSend(OrderSymbol(), OP_SELL, OrderLots(), Bid, 3, LocalStopLoss, LocalTakeProfit, "dongcp", DupMagik, 0, clrLawnGreen);
                                if (TicketForDuplicateOrder > 0)
                                {
                                    Print("reopened");
                                    DuplicateOrderOpened = true;

                                    IsMasterSignalStillTrade = true;
                                    numberOfDupOrderOpen += 1;
                                }
                                else
                                {
                                    Print("duplicate failed ", GetLastError());

                                    SendMail("Fail to open order", "Please check immediately");
                                }
                            }
                        }
                    }

                    if ((activateAdvancedMode == true) && (IsMasterSignalStillTrade == true))
                    {
                        // Open order with lot multiply by 3
                        // This is critical level only
                        if ((LocalStopLoss > 0) && (LocalTakeProfit > 0))
                        {
                            if (masterSignalLotSize > 0)
                            {
                                int ttt = OrderSend(OrderSymbol(), OP_SELL, masterSignalLotSize * 3, Bid, 3, LocalStopLoss, LocalTakeProfit, "dongadv", DupMagik, 0, clrYellow);
                                if (ttt > 0)
                                {
                                    numberOfDupOrderOpen += 1;
                                }
                                else
                                {
                                    SendMail("Advance dup fail", "Please fix it krub");
                                }
                            }
                        }
                    }

                    if ((WasOrderModified > 0) && (ModeDuplication == false))
                    {
                        Print("Modify sell ticket: " + DoubleToStr(OrderTicket(), 0));
                        if (SoundAlert == true)
                            PlaySound(SoundModify);
                    }
                } //End if(OrderType()
                //------------------------------------------------------
                //Closed Market
                if (GetLastError() == 132)
                {
                    MarketClosedCom = true;
                    break;
                }
                //------------------------------------------------------
            } //End if((OrderMagicNumber()...
        }     //End OrderSelect(...
    }         //End for(...

    if (CancelTradingLargeLot == true)
    {
        //Print("The value of large lot is " + DoubleToStr(LargeLotVal));

        if (StringFind(LargeLotOrderCommentToClose, "none", 0) == -1)
        {
            // Close the order now

            Print("Try to closing the lot with LargeLotOrderCommentToClose comment");

            while (CloseOpenOrders(LargeLotOrderCommentToClose) == 0)
            {
                Sleep(100);
            }
        }
    }

    if (activateAdvancedMode == true)
    {

        if ((totalDupProfitUSD + localTotalPipInDDMode) > PipRecoverClose)
        {
            // Close all the trade include master signal too
            CloseOpenOrders("dongadv");

            if (IsMasterSignalStillTrade == true)
            {
                CloseOpenOrders(CommentOfOrder);
            }

            Sleep(300);

            findLatestComment();

            totalDuplicatePipProfit = 0;
            totalDupProfitUSD = 0;
            dupOpenTime = 0;

            // totalDupProfitUSD is the real profit or loss of the order
            // activateAdvancedMode = false;
        }
    }

    // Add the code for handle the closer here (handle the large lot size opened by the master signal

    //------------------------------------------------------
    //Closed market
    if (MarketClosedCom == true)
    {
        MarketClosedCom = true;
        Print(WindowExpertName() + ": Could not run, market is closed!!!");
        Comment("==================",
                "\n   ", WindowExpertName(),
                "\n==================",
                "\n\n\n      Market is closed!!! ",
                "\n\n      Not modify orders. ",
                "\n\n\n\n\n==================");
        Sleep(60000);
    }
    //------------------------------------------------------
}
//====================================================================================================================================================//
void CountOrders()
{
    SumOrders = 0;
    BuyOrders = 0;
    SellOrders = 0;
    AveragePriceBuy = 0;
    AveragePriceSell = 0;
    //---
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (((OrderMagicNumber() == MagicNumber) || (MagicNumber == 0)) || ((OrderMagicNumber() == 0) && (MagicNumber == -1)))
            {
                if (OrderSymbol() == Symbol())
                {
                    if (StringFind(OrderComment(), CommentOfOrder, 0) != -1)
                    {
                        //---Count buy
                        if (OrderType() == OP_BUY)
                        {
                            BuyOrders++;
                            AveragePriceBuy += OrderOpenPrice();
                        }
                        //---Count sell
                        if (OrderType() == OP_SELL)
                        {
                            SellOrders++;
                            AveragePriceSell += OrderOpenPrice();
                        }
                        //---Count all
                        SumOrders++;
                    }
                }
            }
        }
    }
    //---Set average prices
    if (BuyOrders > 0)
        AveragePriceBuy /= BuyOrders;
    if (SellOrders > 0)
        AveragePriceSell /= SellOrders;
    //---
}
//====================================================================================================================================================//
void ChartBackground(string StringName, color ImageColor, int Xposition, int Yposition, int Xsize, int Ysize)
{
    if (ObjectFind(0, StringName) == -1)
    {
        ObjectCreate(0, StringName, OBJ_RECTANGLE_LABEL, 0, 0, 0, 0, 0);
        ObjectSetInteger(0, StringName, OBJPROP_XDISTANCE, Xposition);
        ObjectSetInteger(0, StringName, OBJPROP_YDISTANCE, Yposition);
        ObjectSetInteger(0, StringName, OBJPROP_XSIZE, Xsize);
        ObjectSetInteger(0, StringName, OBJPROP_YSIZE, Ysize);
        ObjectSetInteger(0, StringName, OBJPROP_BGCOLOR, ImageColor);
        ObjectSetInteger(0, StringName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, StringName, OBJPROP_BORDER_COLOR, clrBlack);
        ObjectSetInteger(0, StringName, OBJPROP_BACK, false);
        ObjectSetInteger(0, StringName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, StringName, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, StringName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, StringName, OBJPROP_ZORDER, 0);
    }
}
//====================================================================================================================================================//
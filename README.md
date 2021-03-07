# martingale_ea_improvement (V. 0.1)
To improve the forex robot that use martingale strategy

In forex trading, some martingale robot usually open many orders and close all opened orders at once.
This ea will help improve the effectiveness in martingale trading by hedging the low-lot order (usually 1st to 3rd order opened by the martingale robot)
After the initial few opened orders, then this ea will not hedging the high-lot order, so when the price pullback and the martingale robot can close
all its orders, this ea will close the heding position too. So, it can help is decrease the drawdown and make more profit when the orders is closed.

The original code come from "Nikolaos Pantzos" -> that is Auto TP and SL ea.

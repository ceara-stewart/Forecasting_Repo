# Forecasting_Repo

# Goal:
#    - Forecast a rolling 30-days of total volume.
#    - TODAY is current date and is the start of the forecast period running 30 days from that date.
#    - Need to forecast for channels TPO (Wholesale), Retail, Retail Broker, and Correspondent
#    -

# Current Process (Only working on TPO at moment):
#    - Rolling_30_TPO_Param_Testing: Takes Model A structural loan forecaster class and runs every month total actuals against a list of parameters and tunes the parameters to get a forecasted total volume within +/-  #      5% from actuals when backtesting. 
#    - Convert different parameter sets into different regimes (January Override, Regime 1 or the "steady state", Regime 2, and the transition period between regime 1 and regime 2).
#    - Test the pipeline data against the params for each month and see what pipeline signals correlate to what regime. 

# Currently Editing:
#    - 1st day of month forecast start works
#    - Intra month forecast start doesnt work
#    - Need to fix all issues
#    - Possible issue with base line linking to previous month and cant move. 

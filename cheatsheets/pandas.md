# PANDAS tricks:

# Get elements in df1 that aren't in df2 
(with df1.shape[0] < df2.shape[0])

	mask = df2.isin(df1).all(axis=1)
	ddif = df2[~mask]

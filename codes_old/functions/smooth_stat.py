def smooth_stat(dataset, grouping_features, type_of_stat, target_feature='CustomerInterest', alpha=10):
    '''dataset = set for the grouping
       grouping_feature = what we want to group on
       target_feature = what value should be calculated, here our target variable is by default,
       however, you can use other features, in the best case continous and highly correlated to the target value,
       it can help to prevent overfitting
       type_of_stat: mean min max std
              
       Note: for grouping variables where one has only one observation, 
       I decided to put zero instead f NA when we calculate standard deviation
       however, we can change it if needed
       '''
    #Make sure that grouping variables are categorical, otherwise as_index=False behaves wrongly, also calculating the std, mean etc.
    #dataset_cat = dataset.copy()
    #dataset_cat[grouping_features] = dataset_cat[grouping_features].apply(lambda x: x.astype('str'))
    
    K = dataset.groupby(grouping_features, as_index=False)[target_feature].count()
    
    if (type_of_stat=='std'):
        stat_feat_y = dataset.groupby(grouping_features, as_index=False)[target_feature].count()
        stat_feat_y[target_feature] = dataset.groupby(grouping_features, as_index=False)[target_feature].apply(lambda x : x.std()).as_matrix()
        stat_feat_y[target_feature][stat_feat_y[target_feature].isnull()] = 0
        global_stat_y = dataset[target_feature].std()
        
    elif (type_of_stat=='min'):
        stat_feat_y = dataset.groupby(grouping_features, as_index=False)[target_feature].min()
        global_stat_y = dataset[target_feature].min()
        
    elif (type_of_stat=='max'):
        stat_feat_y = dataset.groupby(grouping_features, as_index=False)[target_feature].max()
        global_stat_y = dataset[target_feature].max()

    elif (type_of_stat=='mean'):
        stat_feat_y = dataset.groupby(grouping_features, as_index=False)[target_feature].mean()
        global_stat_y = dataset[target_feature].mean()
        
    stat_feat_y[target_feature] = (stat_feat_y[target_feature]*K[target_feature] + global_stat_y*alpha)/(K[target_feature]+alpha)
    
    return stat_feat_y
    
def group_and_merge(data_for_calculation, data_to_merge, grouping_feature='CustomerIdx'):
    for stat in ['min', 'max', 'std', 'mean']:
        temp = smooth_stat(data_for_calculation, grouping_feature, type_of_stat=stat)
        temp_df = pd.DataFrame(columns=[f'{grouping_feature}',f'{grouping_feature}_{stat}'])
        temp_df[f'{grouping_feature}'] = temp.index.values
        temp_df[f'{grouping_feature}_{stat}'] = temp
        data_to_merge = data_to_merge.merge(temp_df, on=f'{grouping_feature}', how='left')
    return data_to_merge
    
    
    ### Usage: new_d = group_and_merge(tradedf, tradedf, grouping_feature='CustomerIdx') if you want to store in a new dataset
    ### or you can store in the same one:
    ### tradedf = group_and_merge(tradedf, tradedf, grouping_feature='CustomerIdx')
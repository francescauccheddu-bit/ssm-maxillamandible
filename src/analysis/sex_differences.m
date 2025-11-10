function results = sex_differences(ssm_model, config)
% SEX_DIFFERENCES Statistical testing for sex-based shape differences
%
% Usage:
%   results = sex_differences(ssm_model, config)
%
% Parameters:
%   ssm_model - SSM model from build_ssm()
%   config - Configuration with .analysis settings
%
% Returns:
%   results - Struct with statistical test results

    logger('=== Statistical Analysis: Sex Differences ===', 'level', 'INFO');

    num_pcs = min(config.analysis.num_pcs_to_test, ssm_model.num_components);
    alpha = config.analysis.significance_level;

    % Extract PC scores and sex labels
    pc_scores = ssm_model.pc_scores;  % Nx15 matrix
    sex_labels = ssm_model.metadata.sex;

    % Separate by sex
    is_female = strcmp(sex_labels, 'F');
    is_male = strcmp(sex_labels, 'M');

    num_female = sum(is_female);
    num_male = sum(is_male);

    logger(sprintf('Comparing PC scores: %d females vs %d males', num_female, num_male));
    logger(sprintf('Testing first %d principal components', num_pcs));

    % Initialize results
    results.pc_index = (1:num_pcs)';
    results.variance_explained = ssm_model.variance_explained(1:num_pcs) * 100;
    results.t_statistic = zeros(num_pcs, 1);
    results.p_value = zeros(num_pcs, 1);
    results.p_value_corrected = zeros(num_pcs, 1);
    results.cohens_d = zeros(num_pcs, 1);
    results.significant = false(num_pcs, 1);

    % Perform t-tests for each PC
    for pc = 1:num_pcs
        scores_female = pc_scores(is_female, pc);
        scores_male = pc_scores(is_male, pc);

        % Two-sample t-test
        [h, p, ~, stats] = ttest2(scores_female, scores_male);

        % Cohen's d effect size
        mean_f = mean(scores_female);
        mean_m = mean(scores_male);
        std_pooled = sqrt(((num_female-1)*var(scores_female) + (num_male-1)*var(scores_male)) / (num_female+num_male-2));
        cohens_d = (mean_f - mean_m) / std_pooled;

        % Store results
        results.t_statistic(pc) = stats.tstat;
        results.p_value(pc) = p;
        results.cohens_d(pc) = cohens_d;
    end

    % Bonferroni correction
    if strcmp(config.analysis.correction_method, 'bonferroni')
        alpha_corrected = alpha / num_pcs;
        results.p_value_corrected = results.p_value * num_pcs;
        results.significant = results.p_value_corrected < alpha;
        logger(sprintf('Bonferroni correction applied: alpha = %.4f', alpha_corrected));
    else
        results.p_value_corrected = results.p_value;
        results.significant = results.p_value < alpha;
    end

    % Summary
    num_significant = sum(results.significant);
    logger(sprintf('Significant PCs: %d / %d', num_significant, num_pcs));

    if num_significant > 0
        sig_pcs = find(results.significant);
        for i = 1:length(sig_pcs)
            pc = sig_pcs(i);
            logger(sprintf('  PC%d: p=%.4f, Cohen''s d=%.2f, variance=%.1f%%', ...
                pc, results.p_value_corrected(pc), results.cohens_d(pc), results.variance_explained(pc)));
        end
    end

    % Save results to CSV
    results_table = table(results.pc_index, results.variance_explained, ...
        results.t_statistic, results.p_value, results.p_value_corrected, ...
        results.cohens_d, results.significant, ...
        'VariableNames', {'PC', 'Variance_Pct', 'T_Statistic', 'P_Value', 'P_Corrected', 'Cohens_D', 'Significant'});

    csv_file = fullfile(config.paths.output.results, 'sex_differences.csv');
    writetable(results_table, csv_file);
    logger(sprintf('Results saved to: %s', csv_file));

    results.table = results_table;

end

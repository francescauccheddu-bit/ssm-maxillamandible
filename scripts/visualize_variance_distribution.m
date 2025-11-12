function visualize_variance_distribution(ssm_model_path)
% VISUALIZE_VARIANCE_DISTRIBUTION Visualizza la distribuzione della varianza tra i PC
%
% Syntax:
%   visualize_variance_distribution(ssm_model_path)
%
% Input:
%   ssm_model_path - Percorso al file ssm_model.mat (default: 'output/ssm_model.mat')
%
% Output:
%   Genera figure con:
%   - Varianza spiegata per componente
%   - Varianza cumulativa
%   - Scree plot
%
% Example:
%   visualize_variance_distribution('output/ssm_model.mat')

    %% Setup
    if nargin < 1
        ssm_model_path = 'output/ssm_model.mat';
    end

    % Load SSM model
    fprintf('Loading SSM model from: %s\n', ssm_model_path);
    load(ssm_model_path, 'ssm_model');

    num_components = ssm_model.num_components;
    variance_explained = ssm_model.variance_explained * 100; % Convert to percentage
    cumulative_variance = ssm_model.cumulative_variance * 100;

    %% Create output directory
    output_dir = 'output/variance_analysis';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% Figure 1: Variance Explained per Component
    figure('Position', [100, 100, 1200, 800]);

    % Plot 1: Bar plot of variance explained
    subplot(2, 2, 1);
    bar(1:num_components, variance_explained, 'FaceColor', [0.2 0.4 0.8]);
    xlabel('Principal Component');
    ylabel('Variance Explained (%)');
    title('Variance Explained by Each PC');
    grid on;

    % Add values on top of bars for first 3 PCs
    hold on;
    for i = 1:min(3, num_components)
        text(i, variance_explained(i) + 1, ...
            sprintf('%.2f%%', variance_explained(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
    hold off;

    % Plot 2: Cumulative variance
    subplot(2, 2, 2);
    plot(1:num_components, cumulative_variance, '-o', ...
        'LineWidth', 2, 'MarkerSize', 6, 'Color', [0.8 0.2 0.2]);
    hold on;
    % Add reference lines
    yline(90, '--k', '90%', 'LineWidth', 1.5);
    yline(95, '--k', '95%', 'LineWidth', 1.5);
    yline(99, '--k', '99%', 'LineWidth', 1.5);
    hold off;
    xlabel('Number of Components');
    ylabel('Cumulative Variance (%)');
    title('Cumulative Variance Explained');
    grid on;
    ylim([0 105]);

    % Plot 3: Scree plot (eigenvalues)
    subplot(2, 2, 3);
    semilogy(1:num_components, ssm_model.eigenvalues, '-o', ...
        'LineWidth', 2, 'MarkerSize', 6, 'Color', [0.2 0.6 0.4]);
    xlabel('Principal Component');
    ylabel('Eigenvalue (log scale)');
    title('Scree Plot');
    grid on;

    % Plot 4: First 10 PCs (detailed view)
    subplot(2, 2, 4);
    num_show = min(10, num_components);
    bar(1:num_show, variance_explained(1:num_show), 'FaceColor', [0.6 0.3 0.7]);
    xlabel('Principal Component');
    ylabel('Variance Explained (%)');
    title('Detailed View: First 10 PCs');
    grid on;

    % Add values on bars
    hold on;
    for i = 1:num_show
        text(i, variance_explained(i) + 0.5, ...
            sprintf('%.1f%%', variance_explained(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    hold off;

    % Save figure
    saveas(gcf, fullfile(output_dir, 'variance_distribution.png'));
    saveas(gcf, fullfile(output_dir, 'variance_distribution.fig'));

    %% Print summary statistics
    fprintf('\n========================================\n');
    fprintf('VARIANCE DISTRIBUTION SUMMARY\n');
    fprintf('========================================\n');
    fprintf('Total components: %d\n', num_components);
    fprintf('\nFirst 5 components:\n');
    for i = 1:min(5, num_components)
        fprintf('  PC%d: %.2f%% (cumulative: %.2f%%)\n', ...
            i, variance_explained(i), cumulative_variance(i));
    end

    fprintf('\nKey thresholds:\n');
    idx_90 = find(cumulative_variance >= 90, 1);
    idx_95 = find(cumulative_variance >= 95, 1);
    idx_99 = find(cumulative_variance >= 99, 1);

    if ~isempty(idx_90)
        fprintf('  90%% variance: %d components\n', idx_90);
    end
    if ~isempty(idx_95)
        fprintf('  95%% variance: %d components\n', idx_95);
    end
    if ~isempty(idx_99)
        fprintf('  99%% variance: %d components\n', idx_99);
    end

    fprintf('\nLast component:\n');
    fprintf('  PC%d: %.4f%% (cumulative: %.2f%%)\n', ...
        num_components, variance_explained(end), cumulative_variance(end));

    fprintf('\n========================================\n');
    fprintf('Figures saved to: %s\n', output_dir);
    fprintf('========================================\n\n');

    %% Create a detailed table for first 10 PCs
    fprintf('Detailed table (first 10 PCs):\n');
    fprintf('%-4s | %-12s | %-12s | %-12s\n', 'PC', 'Eigenvalue', 'Variance %', 'Cumulative %');
    fprintf('-----|--------------|--------------|-------------\n');
    for i = 1:min(10, num_components)
        fprintf('%-4d | %12.6f | %12.2f | %12.2f\n', ...
            i, ssm_model.eigenvalues(i), variance_explained(i), cumulative_variance(i));
    end

    %% Save summary to text file
    summary_file = fullfile(output_dir, 'variance_summary.txt');
    fid = fopen(summary_file, 'w');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'VARIANCE DISTRIBUTION SUMMARY\n');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'Total components: %d\n', num_components);
    fprintf(fid, '\nFirst 10 components:\n');
    fprintf(fid, '%-4s | %-12s | %-12s | %-12s\n', 'PC', 'Eigenvalue', 'Variance %%', 'Cumulative %%');
    fprintf(fid, '-----|--------------|--------------|-------------\n');
    for i = 1:min(10, num_components)
        fprintf(fid, '%-4d | %12.6f | %12.2f | %12.2f\n', ...
            i, ssm_model.eigenvalues(i), variance_explained(i), cumulative_variance(i));
    end
    fclose(fid);

    fprintf('Summary saved to: %s\n\n', summary_file);

end

function [X,Y,Z]=reallign2(X,Y,Z,namedValueArgs)
    % Utilizza l'analisi di Procrustes per allineare tutte le surface mesh tra loro.
% Dopo l'allineamento, i punti NON sono normalizzati.

% La funzione iterativa riallinea i dati di training rispetto alla forma media,
% escludendo gli outlier al livello di significatività 0.05.

        arguments
            X (:,:)
            Y (:,:)
            Z (:,:)
            namedValueArgs.initialIdx (1,1)
            namedValueArgs.whetherScaling (1,1) logical = false
        end
        [m,n] = size(X);
        if isfield(namedValueArgs,"initialIdx")
            initialIdx = namedValueArgs.initialIdx;
        else
            initialIdx = 1;
        end
        Template=horzcat(X(:,initialIdx),Y(:,initialIdx),Z(:,initialIdx));%选用户指定或第一个作为template
        % Allinea gli altri n-1 oggetti alla mesh di riferimento (template)
        for i=1:n
            if i ~= initialIdx
                Ytemp= horzcat(X(:,i),Y(:,i),Z(:,i));
                [outlierex]=outexallign(Template,Ytemp,namedValueArgs.whetherScaling);
                X(:,i)=outlierex(:,1);
                Y(:,i)=outlierex(:,2);
                Z(:,i)=outlierex(:,3);
            end
        end
        % Iterazione 2: calcola la forma media aggiornata e la utilizza come nuovo template per l'allineamento successivo.
        Templatenew=horzcat(mean(X,2),mean(Y,2),mean(Z,2));
        for i=1:n
            Ytemp= horzcat(X(:,i),Y(:,i),Z(:,i));
            [outlierex]=outexallign(Templatenew,Ytemp,namedValueArgs.whetherScaling);
            X(:,i)=outlierex(:,1);
            Y(:,i)=outlierex(:,2);
            Z(:,i)=outlierex(:,3);
        end

        Templatenew=horzcat(mean(X,2),mean(Y,2),mean(Z,2));
        for i=1:n
            Ytemp= horzcat(X(:,i),Y(:,i),Z(:,i));
            [outlierex]=outexallign(Templatenew,Ytemp,namedValueArgs.whetherScaling);
            X(:,i)=outlierex(:,1);
            Y(:,i)=outlierex(:,2);
            Z(:,i)=outlierex(:,3);
        end
end

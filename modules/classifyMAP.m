function labels = classifyMAP(Psa_mean)

labels = strings(size(Psa_mean));

for i = 1:length(Psa_mean)
    x = Psa_mean(i);
    if x < 60
        labels(i) = "Out of Bounds (Low)";
    elseif x < 70
        labels(i) = "Hypotension";
    elseif x <= 125
        labels(i) = "Normal";
    elseif x <= 145
        labels(i) = "Hypertension";
    else
        labels(i) = "Out of Bounds (High)";
    end
end

end

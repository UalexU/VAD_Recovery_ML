function saveResultFile(filename, result)
    % Helper function to allow saving simulation results inside a parfor loop
    save(filename, '-struct', 'result');
end

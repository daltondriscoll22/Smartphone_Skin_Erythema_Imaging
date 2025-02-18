% enter your input image file path where ... is
filepath = '...';

img = im2double(imread(filepath));

% extract channels
R = img(:,:,1);
G = img(:,:,2);
B = img(:,:,3);

% image figure
fig = figure('Name', 'Erythema Index Visualization', 'NumberTitle', 'off');

% axes for images
ax1 = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.05, 0.25, 0.4, 0.7]);
ax2 = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.55, 0.25, 0.4, 0.7]);



eq_label = annotation('textbox', [0.32, 0.85, 0.36, 0.1], ...
    'String', '$EI = \\frac{(G - B)^x}{(R - G)^y}$', ...
    'Interpreter', 'latex', 'FontSize', 25, ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center');

% UI controls
x_slider = uicontrol('Style', 'slider', 'Min', 0.1, 'Max', 5, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.05, 0.05, 0.25, 0.05], 'Callback', @updateImage);
uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.05, 0.11, 0.25, 0.03], 'String', 'x');

invertButton = uicontrol('Style', 'pushbutton', 'String', 'Invert', ...
    'Units', 'normalized', 'Position', [0.32, 0.05, 0.36, 0.05], 'Callback', @invert);

y_slider = uicontrol('Style', 'slider', 'Min', 0.1, 'Max', 5, 'Value', 1, ...
    'Units', 'normalized', 'Position', [0.70, 0.05, 0.25, 0.05], 'Callback', @updateImage);
uicontrol('Style', 'text', 'Units', 'normalized', 'Position', [0.70, 0.11, 0.25, 0.03], 'String', 'y');

% store UI elements, image data, etc.
data = struct();
data.x_slider = x_slider;
data.y_slider = y_slider;
data.invertButton = invertButton;
data.ax1 = ax1;
data.ax2 = ax2;
data.equation_text = eq_label;
data.img = img;
data.R = R;
data.G = G;
data.B = B;
data.invert = false; 
guidata(fig, data);

% init image display
updateImage();

function updateImage(~, ~)
    data = guidata(gcf);
    x = get(data.x_slider, 'Value');
    y = get(data.y_slider, 'Value');
    R = data.R;
    G = data.G;
    B = data.B;
    ax1 = data.ax1;
    ax2 = data.ax2;

    % EI calculation
    denominator = (R - G) .^ y;
    denominator(denominator == 0) = eps; % no div by 0
    EI = ((G - B) .^ x) ./ denominator;
    EI = real(EI); % remove imaginary

    % button press -> invert
    if data.invert
        EI(EI == 0) = eps;
        EI = 1 ./ EI;
    end
    
    % replaces non-finite values
    % error handling for sliders 
    EI(~isfinite(EI)) = median(EI(isfinite(EI)), 'omitnan');

    % skin mask
    img_hsv = rgb2hsv(data.img);
    hue = img_hsv(:,:,1);
    saturation = img_hsv(:,:,2);
    value = img_hsv(:,:,3);
    skin_mask = (hue >= 0.01) & (hue <= 0.1) & (saturation >= 0.15) & (value >= 0.2);
    EI = EI .* skin_mask;

    % clip outliers -> remove extreme values
    valid_EI = EI(isfinite(EI)); 
    if ~isempty(valid_EI)
        lower_prctile = prctile(valid_EI, 1);
        upper_prctile = prctile(valid_EI, 99);
        EI(EI < lower_prctile) = lower_prctile;
        EI(EI > upper_prctile) = upper_prctile;
    end

    % normalize
    EI_normalized = (EI - min(EI(:))) / (max(EI(:)) - min(EI(:)) + eps);
    EI_log = log10(EI_normalized + 1);
    EI_log = (EI_log - min(EI_log(:))) / (max(EI_log(:)) - min(EI_log(:)) + eps);

    % update image display
    imshow(data.img, 'Parent', ax1);
    title(ax1, 'Original Image');
    imshow(EI_log, [], 'Parent', ax2);
    title(ax2, sprintf('Erythema Index (x = %.2f, y = %.2f, invert: %s)', x, y, string(data.invert)));

    % update equation display
    equation_str = sprintf('$EI = \\frac{(G - B)^{%.2f}}{(R - G)^{%.2f}}$', x, y);
    if isvalid(data.equation_text) 
        set(data.equation_text, 'String', equation_str);
    end
end

function invert(~, ~)
    data = guidata(gcf);
    data.invert = ~data.invert;
    guidata(gcf, data);
    updateImage();
end

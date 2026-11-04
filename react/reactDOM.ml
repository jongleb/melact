open Melact_view

module Style = struct
  type t = Declarations of (string * string) list [@@unboxed]

  let make ?azimuth ?background ?backgroundAttachment ?backgroundColor ?backgroundImage ?backgroundPosition ?backgroundRepeat ?border ?borderCollapse ?borderColor ?borderSpacing ?borderStyle ?borderTop ?borderRight ?borderBottom ?borderLeft ?borderTopColor ?borderRightColor ?borderBottomColor ?borderLeftColor ?borderTopStyle ?borderRightStyle ?borderBottomStyle ?borderLeftStyle ?borderTopWidth ?borderRightWidth ?borderBottomWidth ?borderLeftWidth ?borderWidth ?bottom ?captionSide ?clear ?clip ?color ?content ?counterIncrement ?counterReset ?cue ?cueAfter ?cueBefore ?cursor ?direction ?display ?elevation ?emptyCells ?float ?font ?fontFamily ?fontSize ?fontSizeAdjust ?fontStretch ?fontStyle ?fontVariant ?fontWeight ?height ?left ?letterSpacing ?lineHeight ?listStyle ?listStyleImage ?listStylePosition ?listStyleType ?margin ?marginTop ?marginRight ?marginBottom ?marginLeft ?markerOffset ?marks ?maxHeight ?maxWidth ?minHeight ?minWidth ?orphans ?outline ?outlineColor ?outlineStyle ?outlineWidth ?overflow ?overflowX ?overflowY ?padding ?paddingTop ?paddingRight ?paddingBottom ?paddingLeft ?page ?pageBreakAfter ?pageBreakBefore ?pageBreakInside ?pause ?pauseAfter ?pauseBefore ?pitch ?pitchRange ?playDuring ?position ?quotes ?richness ?right ?size ?speak ?speakHeader ?speakNumeral ?speakPunctuation ?speechRate ?stress ?tableLayout ?textAlign ?textDecoration ?textIndent ?textShadow ?textTransform ?top ?unicodeBidi ?verticalAlign ?visibility ?voiceFamily ?volume ?whiteSpace ?widows ?width ?wordSpacing ?zIndex ?opacity ?backgroundOrigin ?backgroundSize ?backgroundClip ?borderRadius ?borderTopLeftRadius ?borderTopRightRadius ?borderBottomLeftRadius ?borderBottomRightRadius ?borderImage ?borderImageSource ?borderImageSlice ?borderImageWidth ?borderImageOutset ?borderImageRepeat ?boxShadow ?columns ?columnCount ?columnFill ?columnGap ?columnRule ?columnRuleColor ?columnRuleStyle ?columnRuleWidth ?columnSpan ?columnWidth ?breakAfter ?breakBefore ?breakInside ?rest ?restAfter ?restBefore ?speakAs ?voiceBalance ?voiceDuration ?voicePitch ?voiceRange ?voiceRate ?voiceStress ?voiceVolume ?objectFit ?objectPosition ?imageResolution ?imageOrientation ?alignContent ?alignItems ?alignSelf ?flex ?flexBasis ?flexDirection ?flexFlow ?flexGrow ?flexShrink ?flexWrap ?justifyContent ?order ?textDecorationColor ?textDecorationLine ?textDecorationSkip ?textDecorationStyle ?textEmphasis ?textEmphasisColor ?textEmphasisPosition ?textEmphasisStyle ?textUnderlinePosition ?fontFeatureSettings ?fontKerning ?fontLanguageOverride ?fontSynthesis ?forntVariantAlternates ?fontVariantCaps ?fontVariantEastAsian ?fontVariantLigatures ?fontVariantNumeric ?fontVariantPosition ?all ?glyphOrientationVertical ?textCombineUpright ?textOrientation ?writingMode ?shapeImageThreshold ?shapeMargin ?shapeOutside ?clipPath ?clipRule ?mask ?maskBorder ?maskBorderMode ?maskBorderOutset ?maskBorderRepeat ?maskBorderSlice ?maskBorderSource ?maskBorderWidth ?maskClip ?maskComposite ?maskImage ?maskMode ?maskOrigin ?maskPosition ?maskRepeat ?maskSize ?maskType ?backgroundBlendMode ?isolation ?mixBlendMode ?boxDecorationBreak ?boxSizing ?caretColor ?navDown ?navLeft ?navRight ?navUp ?outlineOffset ?resize ?textOverflow ?grid ?gridArea ?gridAutoColumns ?gridAutoFlow ?gridAutoRows ?gridColumn ?gridColumnEnd ?gridColumnGap ?gridColumnStart ?gridGap ?gridRow ?gridRowEnd ?gridRowGap ?gridRowStart ?gridTemplate ?gridTemplateAreas ?gridTemplateColumns ?gridTemplateRows ?willChange ?hangingPunctuation ?hyphens ?lineBreak ?overflowWrap ?tabSize ?textAlignLast ?textJustify ?wordBreak ?wordWrap ?animation ?animationDelay ?animationDirection ?animationDuration ?animationFillMode ?animationIterationCount ?animationName ?animationPlayState ?animationTimingFunction ?transition ?transitionDelay ?transitionDuration ?transitionProperty ?transitionTimingFunction ?backfaceVisibility ?perspective ?perspectiveOrigin ?transform ?transformOrigin ?transformStyle ?justifyItems ?justifySelf ?placeContent ?placeItems ?placeSelf ?appearance ?caret ?caretAnimation ?caretShape ?userSelect ?maxLines ?marqueeDirection ?marqueeLoop ?marqueeSpeed ?marqueeStyle ?overflowStyle ?rotation ?rotationPoint ?alignmentBaseline ?baselineShift ?colorInterpolation ?colorInterpolationFilters ?colorProfile ?colorRendering ?dominantBaseline ?fill ?fillOpacity ?fillRule ?filter ?floodColor ?floodOpacity ?glyphOrientationHorizontal ?imageRendering ?kerning ?lightingColor ?markerEnd ?markerMid ?markerStart ?pointerEvents ?shapeRendering ?stopColor ?stopOpacity ?stroke ?strokeDasharray ?strokeDashoffset ?strokeLinecap ?strokeLinejoin ?strokeMiterlimit ?strokeOpacity ?strokeWidth ?textAnchor ?textRendering ?rubyAlign ?rubyMerge ?rubyPosition ?gap ?rowGap () =
    Declarations
      (List.filter_map
         (fun (name, value) -> Option.map (fun value -> (name, value)) value)
         [
           ("azimuth", azimuth);
           ("background", background);
           ("backgroundAttachment", backgroundAttachment);
           ("backgroundColor", backgroundColor);
           ("backgroundImage", backgroundImage);
           ("backgroundPosition", backgroundPosition);
           ("backgroundRepeat", backgroundRepeat);
           ("border", border);
           ("borderCollapse", borderCollapse);
           ("borderColor", borderColor);
           ("borderSpacing", borderSpacing);
           ("borderStyle", borderStyle);
           ("borderTop", borderTop);
           ("borderRight", borderRight);
           ("borderBottom", borderBottom);
           ("borderLeft", borderLeft);
           ("borderTopColor", borderTopColor);
           ("borderRightColor", borderRightColor);
           ("borderBottomColor", borderBottomColor);
           ("borderLeftColor", borderLeftColor);
           ("borderTopStyle", borderTopStyle);
           ("borderRightStyle", borderRightStyle);
           ("borderBottomStyle", borderBottomStyle);
           ("borderLeftStyle", borderLeftStyle);
           ("borderTopWidth", borderTopWidth);
           ("borderRightWidth", borderRightWidth);
           ("borderBottomWidth", borderBottomWidth);
           ("borderLeftWidth", borderLeftWidth);
           ("borderWidth", borderWidth);
           ("bottom", bottom);
           ("captionSide", captionSide);
           ("clear", clear);
           ("clip", clip);
           ("color", color);
           ("content", content);
           ("counterIncrement", counterIncrement);
           ("counterReset", counterReset);
           ("cue", cue);
           ("cueAfter", cueAfter);
           ("cueBefore", cueBefore);
           ("cursor", cursor);
           ("direction", direction);
           ("display", display);
           ("elevation", elevation);
           ("emptyCells", emptyCells);
           ("float", float);
           ("font", font);
           ("fontFamily", fontFamily);
           ("fontSize", fontSize);
           ("fontSizeAdjust", fontSizeAdjust);
           ("fontStretch", fontStretch);
           ("fontStyle", fontStyle);
           ("fontVariant", fontVariant);
           ("fontWeight", fontWeight);
           ("height", height);
           ("left", left);
           ("letterSpacing", letterSpacing);
           ("lineHeight", lineHeight);
           ("listStyle", listStyle);
           ("listStyleImage", listStyleImage);
           ("listStylePosition", listStylePosition);
           ("listStyleType", listStyleType);
           ("margin", margin);
           ("marginTop", marginTop);
           ("marginRight", marginRight);
           ("marginBottom", marginBottom);
           ("marginLeft", marginLeft);
           ("markerOffset", markerOffset);
           ("marks", marks);
           ("maxHeight", maxHeight);
           ("maxWidth", maxWidth);
           ("minHeight", minHeight);
           ("minWidth", minWidth);
           ("orphans", orphans);
           ("outline", outline);
           ("outlineColor", outlineColor);
           ("outlineStyle", outlineStyle);
           ("outlineWidth", outlineWidth);
           ("overflow", overflow);
           ("overflowX", overflowX);
           ("overflowY", overflowY);
           ("padding", padding);
           ("paddingTop", paddingTop);
           ("paddingRight", paddingRight);
           ("paddingBottom", paddingBottom);
           ("paddingLeft", paddingLeft);
           ("page", page);
           ("pageBreakAfter", pageBreakAfter);
           ("pageBreakBefore", pageBreakBefore);
           ("pageBreakInside", pageBreakInside);
           ("pause", pause);
           ("pauseAfter", pauseAfter);
           ("pauseBefore", pauseBefore);
           ("pitch", pitch);
           ("pitchRange", pitchRange);
           ("playDuring", playDuring);
           ("position", position);
           ("quotes", quotes);
           ("richness", richness);
           ("right", right);
           ("size", size);
           ("speak", speak);
           ("speakHeader", speakHeader);
           ("speakNumeral", speakNumeral);
           ("speakPunctuation", speakPunctuation);
           ("speechRate", speechRate);
           ("stress", stress);
           ("tableLayout", tableLayout);
           ("textAlign", textAlign);
           ("textDecoration", textDecoration);
           ("textIndent", textIndent);
           ("textShadow", textShadow);
           ("textTransform", textTransform);
           ("top", top);
           ("unicodeBidi", unicodeBidi);
           ("verticalAlign", verticalAlign);
           ("visibility", visibility);
           ("voiceFamily", voiceFamily);
           ("volume", volume);
           ("whiteSpace", whiteSpace);
           ("widows", widows);
           ("width", width);
           ("wordSpacing", wordSpacing);
           ("zIndex", zIndex);
           ("opacity", opacity);
           ("backgroundOrigin", backgroundOrigin);
           ("backgroundSize", backgroundSize);
           ("backgroundClip", backgroundClip);
           ("borderRadius", borderRadius);
           ("borderTopLeftRadius", borderTopLeftRadius);
           ("borderTopRightRadius", borderTopRightRadius);
           ("borderBottomLeftRadius", borderBottomLeftRadius);
           ("borderBottomRightRadius", borderBottomRightRadius);
           ("borderImage", borderImage);
           ("borderImageSource", borderImageSource);
           ("borderImageSlice", borderImageSlice);
           ("borderImageWidth", borderImageWidth);
           ("borderImageOutset", borderImageOutset);
           ("borderImageRepeat", borderImageRepeat);
           ("boxShadow", boxShadow);
           ("columns", columns);
           ("columnCount", columnCount);
           ("columnFill", columnFill);
           ("columnGap", columnGap);
           ("columnRule", columnRule);
           ("columnRuleColor", columnRuleColor);
           ("columnRuleStyle", columnRuleStyle);
           ("columnRuleWidth", columnRuleWidth);
           ("columnSpan", columnSpan);
           ("columnWidth", columnWidth);
           ("breakAfter", breakAfter);
           ("breakBefore", breakBefore);
           ("breakInside", breakInside);
           ("rest", rest);
           ("restAfter", restAfter);
           ("restBefore", restBefore);
           ("speakAs", speakAs);
           ("voiceBalance", voiceBalance);
           ("voiceDuration", voiceDuration);
           ("voicePitch", voicePitch);
           ("voiceRange", voiceRange);
           ("voiceRate", voiceRate);
           ("voiceStress", voiceStress);
           ("voiceVolume", voiceVolume);
           ("objectFit", objectFit);
           ("objectPosition", objectPosition);
           ("imageResolution", imageResolution);
           ("imageOrientation", imageOrientation);
           ("alignContent", alignContent);
           ("alignItems", alignItems);
           ("alignSelf", alignSelf);
           ("flex", flex);
           ("flexBasis", flexBasis);
           ("flexDirection", flexDirection);
           ("flexFlow", flexFlow);
           ("flexGrow", flexGrow);
           ("flexShrink", flexShrink);
           ("flexWrap", flexWrap);
           ("justifyContent", justifyContent);
           ("order", order);
           ("textDecorationColor", textDecorationColor);
           ("textDecorationLine", textDecorationLine);
           ("textDecorationSkip", textDecorationSkip);
           ("textDecorationStyle", textDecorationStyle);
           ("textEmphasis", textEmphasis);
           ("textEmphasisColor", textEmphasisColor);
           ("textEmphasisPosition", textEmphasisPosition);
           ("textEmphasisStyle", textEmphasisStyle);
           ("textUnderlinePosition", textUnderlinePosition);
           ("fontFeatureSettings", fontFeatureSettings);
           ("fontKerning", fontKerning);
           ("fontLanguageOverride", fontLanguageOverride);
           ("fontSynthesis", fontSynthesis);
           ("forntVariantAlternates", forntVariantAlternates);
           ("fontVariantCaps", fontVariantCaps);
           ("fontVariantEastAsian", fontVariantEastAsian);
           ("fontVariantLigatures", fontVariantLigatures);
           ("fontVariantNumeric", fontVariantNumeric);
           ("fontVariantPosition", fontVariantPosition);
           ("all", all);
           ("glyphOrientationVertical", glyphOrientationVertical);
           ("textCombineUpright", textCombineUpright);
           ("textOrientation", textOrientation);
           ("writingMode", writingMode);
           ("shapeImageThreshold", shapeImageThreshold);
           ("shapeMargin", shapeMargin);
           ("shapeOutside", shapeOutside);
           ("clipPath", clipPath);
           ("clipRule", clipRule);
           ("mask", mask);
           ("maskBorder", maskBorder);
           ("maskBorderMode", maskBorderMode);
           ("maskBorderOutset", maskBorderOutset);
           ("maskBorderRepeat", maskBorderRepeat);
           ("maskBorderSlice", maskBorderSlice);
           ("maskBorderSource", maskBorderSource);
           ("maskBorderWidth", maskBorderWidth);
           ("maskClip", maskClip);
           ("maskComposite", maskComposite);
           ("maskImage", maskImage);
           ("maskMode", maskMode);
           ("maskOrigin", maskOrigin);
           ("maskPosition", maskPosition);
           ("maskRepeat", maskRepeat);
           ("maskSize", maskSize);
           ("maskType", maskType);
           ("backgroundBlendMode", backgroundBlendMode);
           ("isolation", isolation);
           ("mixBlendMode", mixBlendMode);
           ("boxDecorationBreak", boxDecorationBreak);
           ("boxSizing", boxSizing);
           ("caretColor", caretColor);
           ("navDown", navDown);
           ("navLeft", navLeft);
           ("navRight", navRight);
           ("navUp", navUp);
           ("outlineOffset", outlineOffset);
           ("resize", resize);
           ("textOverflow", textOverflow);
           ("grid", grid);
           ("gridArea", gridArea);
           ("gridAutoColumns", gridAutoColumns);
           ("gridAutoFlow", gridAutoFlow);
           ("gridAutoRows", gridAutoRows);
           ("gridColumn", gridColumn);
           ("gridColumnEnd", gridColumnEnd);
           ("gridColumnGap", gridColumnGap);
           ("gridColumnStart", gridColumnStart);
           ("gridGap", gridGap);
           ("gridRow", gridRow);
           ("gridRowEnd", gridRowEnd);
           ("gridRowGap", gridRowGap);
           ("gridRowStart", gridRowStart);
           ("gridTemplate", gridTemplate);
           ("gridTemplateAreas", gridTemplateAreas);
           ("gridTemplateColumns", gridTemplateColumns);
           ("gridTemplateRows", gridTemplateRows);
           ("willChange", willChange);
           ("hangingPunctuation", hangingPunctuation);
           ("hyphens", hyphens);
           ("lineBreak", lineBreak);
           ("overflowWrap", overflowWrap);
           ("tabSize", tabSize);
           ("textAlignLast", textAlignLast);
           ("textJustify", textJustify);
           ("wordBreak", wordBreak);
           ("wordWrap", wordWrap);
           ("animation", animation);
           ("animationDelay", animationDelay);
           ("animationDirection", animationDirection);
           ("animationDuration", animationDuration);
           ("animationFillMode", animationFillMode);
           ("animationIterationCount", animationIterationCount);
           ("animationName", animationName);
           ("animationPlayState", animationPlayState);
           ("animationTimingFunction", animationTimingFunction);
           ("transition", transition);
           ("transitionDelay", transitionDelay);
           ("transitionDuration", transitionDuration);
           ("transitionProperty", transitionProperty);
           ("transitionTimingFunction", transitionTimingFunction);
           ("backfaceVisibility", backfaceVisibility);
           ("perspective", perspective);
           ("perspectiveOrigin", perspectiveOrigin);
           ("transform", transform);
           ("transformOrigin", transformOrigin);
           ("transformStyle", transformStyle);
           ("justifyItems", justifyItems);
           ("justifySelf", justifySelf);
           ("placeContent", placeContent);
           ("placeItems", placeItems);
           ("placeSelf", placeSelf);
           ("appearance", appearance);
           ("caret", caret);
           ("caretAnimation", caretAnimation);
           ("caretShape", caretShape);
           ("userSelect", userSelect);
           ("maxLines", maxLines);
           ("marqueeDirection", marqueeDirection);
           ("marqueeLoop", marqueeLoop);
           ("marqueeSpeed", marqueeSpeed);
           ("marqueeStyle", marqueeStyle);
           ("overflowStyle", overflowStyle);
           ("rotation", rotation);
           ("rotationPoint", rotationPoint);
           ("alignmentBaseline", alignmentBaseline);
           ("baselineShift", baselineShift);
           ("colorInterpolation", colorInterpolation);
           ("colorInterpolationFilters", colorInterpolationFilters);
           ("colorProfile", colorProfile);
           ("colorRendering", colorRendering);
           ("dominantBaseline", dominantBaseline);
           ("fill", fill);
           ("fillOpacity", fillOpacity);
           ("fillRule", fillRule);
           ("filter", filter);
           ("floodColor", floodColor);
           ("floodOpacity", floodOpacity);
           ("glyphOrientationHorizontal", glyphOrientationHorizontal);
           ("imageRendering", imageRendering);
           ("kerning", kerning);
           ("lightingColor", lightingColor);
           ("markerEnd", markerEnd);
           ("markerMid", markerMid);
           ("markerStart", markerStart);
           ("pointerEvents", pointerEvents);
           ("shapeRendering", shapeRendering);
           ("stopColor", stopColor);
           ("stopOpacity", stopOpacity);
           ("stroke", stroke);
           ("strokeDasharray", strokeDasharray);
           ("strokeDashoffset", strokeDashoffset);
           ("strokeLinecap", strokeLinecap);
           ("strokeLinejoin", strokeLinejoin);
           ("strokeMiterlimit", strokeMiterlimit);
           ("strokeOpacity", strokeOpacity);
           ("strokeWidth", strokeWidth);
           ("textAnchor", textAnchor);
           ("textRendering", textRendering);
           ("rubyAlign", rubyAlign);
           ("rubyMerge", rubyMerge);
           ("rubyPosition", rubyPosition);
           ("gap", gap);
           ("rowGap", rowGap);
         ])

  let combine (Declarations first) (Declarations second) = Declarations (first @ second)

  let unsafeAddProp (Declarations declarations) name value =
    Declarations (declarations @ [ (name, value) ])

  let declarations (Declarations declarations) = declarations
end

type domRef =
  | Current of Dom.element Js.nullable React.ref
  | Callback of (Dom.element Js.nullable -> unit)

module Ref = struct
  let domRef target = Current target
  let callbackDomRef apply = Callback apply

  let attach reference element =
    match reference with
    | Current target -> target.current <- Js.Nullable.return element
    | Callback apply -> apply (Js.Nullable.return element)

  let forwarded reference =
    match reference with
    | Some (Current target) -> Js.Nullable.return target
    | Some (Callback _) | None -> Js.Nullable.null
end

external set_text_content : Dom.element -> string -> unit = "textContent" [@@mel.set]
external querySelector : string -> Dom.element option = "querySelector"
[@@mel.scope "document"] [@@mel.return nullable]
external domElementToObj : Dom.element -> < .. > Js.t = "%identity"

let clear container = set_text_content container ""

module Client = struct
  (** What a root shows. *)
  type content = Nothing | Showing of View.mounted

  type root = { container : Dom.element; mutable content : content }

  let createRoot container = { container; content = Nothing }

  let render root (React.Element child) =
    match root.content with
    | Showing mounted -> View.patch mounted child
    | Nothing ->
        root.content <- Showing (View.mount child ~parent:root.container ~before:None)

  let hydrateRoot container element =
    clear container;
    let root = createRoot container in
    render root element;
    root

  let unmount root () =
    match root.content with
    | Showing mounted ->
        View.unmount mounted;
        root.content <- Nothing
    | Nothing -> ()
end

let roots = ref []

let render element container =
  let root =
    match List.find_opt (fun (known, _) -> known == container) !roots with
    | Some (_, root) -> root
    | None ->
        let root = Client.createRoot container in
        roots := (container, root) :: !roots;
        root
  in
  Client.render root element

let hydrate element container =
  clear container;
  render element container

let createPortal (React.Element child) container = React.Element (View.portal container child)

let unmountComponentAtNode container =
  Option.iter
    (fun (_, root) ->
      Client.unmount root ();
      roots := List.filter (fun (known, _) -> not (known == container)) !roots)
    (List.find_opt (fun (known, _) -> known == container) !roots)

let flushSync run =
  run ();
  View.flush ()

--[[
  A mostly LuaJIT optimized simulator of the Cook Political Swingometer.

  See https://cookpolitical.com/swingometer for details.

  The creation of FFI objects could be optimized a *lot* better, but I
  lost interest in optimizing this further. This was initially written
  as pure Lua 5.1, so not everything is tailored to match FFI idioms.
  As a result, performance is deeply suboptimal.
]]--

local ffi = require 'ffi'

ffi.cdef [[
  typedef struct {
    double cew, ncw, aa, hl, ao;
  } demographics_t;

  typedef union {
    double underlying[5];
    demographics_t demographics;
  } cvap_t;

  typedef union {
    double underlying[5];
    demographics_t demographics;
  } turnout_t;

  typedef union {
    double underlying[5];
    demographics_t demographics;
  } bidenshare_t;

  typedef struct {
    const char *name;
    unsigned electoral_votes;
    double other_offset;
    cvap_t cvap;
    turnout_t turnout;
    bidenshare_t bidenshare;
  } state_t;
]]

local function make_state(name, electoral_votes, cew_cvap, ncw_cvap, aa_cvap,
                          hl_cvap, ao_cvap, cew_turnout, ncw_turnout,
                          aa_turnout, hl_turnout, ao_turnout, cew_bidenshare,
                          ncw_bidenshare, aa_bidenshare, hl_bidenshare,
                          ao_bidenshare, x_coord, y_coord, state_num,
                          center_x, center_y, other_offset)
  return ffi.new('state_t',
    ffi.new('const char*', name),
    electoral_votes,
    other_offset,
    ffi.new('cvap_t',
      {underlying = {cew_cvap, ncw_cvap, aa_cvap, hl_cvap, ao_cvap}}
    ),
    ffi.new('turnout_t',
      {underlying = {cew_turnout, ncw_turnout, aa_turnout, hl_turnout, ao_turnout}}
    ),
    ffi.new('bidenshare_t',
      {underlying = {cew_bidenshare, ncw_bidenshare, aa_bidenshare, hl_bidenshare, ao_bidenshare}}
    )
  )
end

local state_data = {
  {'AL', 9, 731223, 1819927, 974635, 78100, 98840, 0.712312749, 0.500954768, 0.593503405, 0.467375686, 0.453523095, 0.244488685, 0.094402522, 0.866702241, 0.569889926, 0.523310662, 6, 1, 1, 674, 424, 0.964164057, 758998, 1333194},
  {'AK', 3, 127784, 223956, 16340, 31550, 133330, 0.674782222, 0.549315484, 0.493222323, 0.411942484, 0.381023036, 0.427678072, 0.268128608, 0.903735272, 0.655679589, 0.653355141, 0, 6, 2, 105, 512, 0.877325532, 118854, 162233},
  {'AZ', 11, 1147475, 2029470, 218385, 1192695, 423930, 0.686411712, 0.52788103, 0.453052058, 0.407984747, 0.381478884, 0.475750456, 0.355253975, 0.920439975, 0.669454521, 0.651487731, 2, 2, 4, 205, 374, 0.937599544, 1277429, 1328615},
  {'AR', 6, 442136, 1281284, 333780, 81800, 77400, 0.634658637, 0.456810066, 0.485147072, 0.402445684, 0.384014514, 0.367973125, 0.190255708, 0.888132704, 0.622614878, 0.614572031, 5, 2, 5, 564, 386, 0.941616928, 397174, 693218},
  {'CA', 55, 5310431, 6548569, 1693080, 7856780, 4473805, 0.729158587, 0.544953064, 0.466807298, 0.435049418, 0.496064575, 0.696443438, 0.41978554, 0.943038862, 0.760830943, 0.800855853, 1, 3, 6, 75, 283, 0.932847866, 9317752, 4550154},
  {'CO', 9, 1493714, 1622521, 159145, 653755, 205075, 0.766013453, 0.637501822, 0.721727607, 0.552141755, 0.460278535, 0.599658046, 0.347347992, 0.939137966, 0.713128144, 0.686989924, 3, 3, 8, 330, 284, 0.913331221, 1475471, 1273127},
  {'CT', 7, 862537, 1063808, 249270, 321690, 121770, 0.750719177, 0.567975263, 0.537240697, 0.464714604, 0.455245573, 0.612181688, 0.411053296, 0.945677509, 0.742904456, 0.738898385, 10, 4, 9, 886, 190, 0.954658269, 923383, 667098},
  {'DE', 3, 173219, 322216, 154025, 39340, 29765, 0.751368589, 0.586182749, 0.570155321, 0.476340147, 0.454341838, 0.584066172, 0.361529588, 0.937756343, 0.725700366, 0.726169876, 11, 3, 10, 853, 258, 0.947753196, 250061, 189018},
  {'DC', 3, 202176, 17459, 243420, 35605, 29630, 0.680857203, 0.557687735, 0.58593222, 0.399771933, 0.382426351, 0.932832074, 0.835253821, 0.990097882, 0.934690463, 0.946003988, 9, 3, 11, 829, 264, 0.948656564, 301774, 13803},
  {'FL', 29, 3182791, 6140609, 2216425, 3129910, 582600, 0.785832045, 0.622056216, 0.580982552, 0.602414311, 0.544332448, 0.433641214, 0.316362394, 0.920325727, 0.665234816, 0.684924408, 8, 0, 12, 787, 520, 0.968186164, 4949452, 4861206},
  {'GA', 16, 1554777, 2791253, 2401875, 357900, 339780, 0.729358396, 0.523562595, 0.557437922, 0.451408656, 0.242333293, 0.380818831, 0.150036063, 0.910889203, 0.689096127, 0.66855494, 7, 1, 13, 734, 419, 0.964015185, 2037027, 2140911},
  {'HI', 4, 123898, 138487, 21075, 89315, 653610, 0.610715828, 0.411306659, 0.459276787, 0.402353158, 0.345719783, 0.630085862, 0.44230144, 0.940539401, 0.740197705, 0.732632251, 0, 0, 15, 272, 570, 0.922451948, 274119, 130079},
  {'ID', 4, 318290, 759990, 6715, 101815, 49775, 0.639722713, 0.503144875, 0.472749432, 0.349918541, 0.366204847, 0.422896394, 0.22326973, 0.899662795, 0.635094939, 0.6307272, 2, 5, 16, 195, 148, 0.866637312, 208448, 434523},
  {'IL', 20, 2443634, 3751206, 1333820, 1055375, 522855, 0.712772153, 0.550515875, 0.557058234, 0.453474042, 0.517795798, 0.642466628, 0.381443647, 0.941720977, 0.759612127, 0.765280739, 6, 5, 17, 614, 264, 0.945331763, 3177029, 2121809},
  {'IN', 11, 1165522, 2976783, 437620, 202545, 145415, 0.7013387, 0.49284417, 0.488397782, 0.423949968, 0.560472236, 0.447947057, 0.281396845, 0.906477466, 0.683130513, 0.671213319, 6, 4, 18, 669, 264, 0.946533215, 1086036, 1579349},
  {'IA', 6, 633723, 1480847, 65760, 82080, 67880, 0.75561711, 0.600103339, 0.575898492, 0.505952256, 0.487797651, 0.531077435, 0.374946097, 0.93993856, 0.714634042, 0.690276502, 5, 4, 19, 536, 223, 0.928220195, 675583, 804301},
  {'KS', 6, 634952, 1088073, 117325, 151275, 101730, 0.68523081, 0.502378643, 0.390024061, 0.412499033, 0.261845637, 0.467740399, 0.25652278, 0.917396004, 0.661228812, 0.660686747, 4, 2, 20, 457, 307, 0.926351989, 444544, 671876},
  {'KY', 8, 736848, 2226212, 257745, 59080, 82715, 0.708151905, 0.498909168, 0.666915214, 0.461737209, 0.445157833, 0.403435773, 0.22071428, 0.904114246, 0.642923245, 0.645393807, 6, 3, 21, 706, 314, 0.95160255, 652329, 1215970},
  {'LA', 8, 624270, 1542735, 1097845, 105840, 102805, 0.705760429, 0.536956714, 0.560881337, 0.608232383, 0.37538006, 0.283671837, 0.096499813, 0.877018165, 0.588697839, 0.540236279, 4, 1, 22, 560, 456, 0.965206395, 803684, 1183878},
  {'ME', 2, 330840, 683685, 7595, 14365, 30730, 0.757584652, 0.632260487, 0.516915013, 0.439171155, 0.414400546, 0.675620779, 0.425763251, 0.949330929, 0.749376636, 0.699605879, 11, 7, 23, 919, 92, 0.926156809, 370713, 335093},
  {'MD', 10, 1127501, 1326039, 1305890, 236030, 317055, 0.735217694, 0.553560247, 0.626151988, 0.581983019, 0.543516313, 0.598244937, 0.328318768, 0.953451659, 0.763745826, 0.769218962, 10, 3, 24, 825, 254, 0.942106516, 1753962, 936285},
  {'MA', 11, 1900168, 2058757, 314310, 450405, 318405, 0.747214813, 0.595050337, 0.629960992, 0.424185608, 0.470108339, 0.724469344, 0.495629829, 0.964642071, 0.786342936, 0.803774487, 10, 5, 25, 895, 169, 0.92738661, 2097235, 1086187},
  {'MI', 16, 1842720, 4107175, 1007370, 258370, 321080, 0.761990262, 0.58088414, 0.60233162, 0.361031375, 0.462821577, 0.53046672, 0.357191632, 0.946486569, 0.653109607, 0.692518292, 7, 5, 26, 681, 190, 0.947174848, 2335020, 2303178},
  {'MN', 10, 1357092, 2175703, 195005, 119085, 247230, 0.764415716, 0.647984664, 0.694528419, 0.419904883, 0.555841069, 0.627233628, 0.370535993, 0.949118262, 0.734846514, 0.737085977, 5, 5, 27, 519, 120, 0.912972527, 1439558, 1330275},
  {'MS', 6, 351060, 978600, 828760, 37925, 43210, 0.637355917, 0.504938164, 0.545275297, 0.362560871, 0.348758865, 0.224739243, 0.086451613, 0.867677527, 0.571917782, 0.505954102, 5, 1, 28, 617, 427, 0.980513683, 500590, 697937},
  {'MO', 10, 1171412, 2662468, 513880, 121890, 154460, 0.719027094, 0.546234738, 0.603308744, 0.427206222, 0.369821221, 0.435678401, 0.258473289, 0.934346221, 0.667447135, 0.665886109, 5, 3, 29, 557, 305, 0.948707287, 1105269, 1610330},
  {'MT', 3, 244281, 482394, 3290, 25330, 63735, 0.708726725, 0.548668068, 0.48369807, 0.420899516, 0.401094129, 0.495278842, 0.288394588, 0.917974786, 0.679318597, 0.678039409, 3, 5, 30, 289, 95, 0.918482182, 188100, 287476},
  {'NE', 2, 413008, 769797, 59050, 85865, 48835, 0.690755988, 0.561661783, 0.489987146, 0.410693361, 0.389334128, 0.450071157, 0.254647403, 0.911229732, 0.65367782, 0.653847539, 4, 3, 31, 438, 238, 0.92345076, 300329, 500465},
  {'NV', 6, 367042, 837078, 192395, 396920, 251585, 0.711453404, 0.537389189, 0.600584942, 0.510767634, 0.399708575, 0.484871229, 0.364279378, 0.884121437, 0.683622208, 0.614821827, 2, 4, 32, 136, 240, 0.933636351, 593035, 536707},
  {'NH', 4, 369752, 621268, 11910, 30795, 35045, 0.771422546, 0.638352455, 0.572569146, 0.51083004, 0.489034853, 0.595084336, 0.421954167, 0.94222865, 0.734239498, 0.683631935, 11, 6, 33, 895, 146, 0.932332004, 366744, 354703},
  {'NJ', 14, 1739647, 2136013, 818095, 930895, 523305, 0.767592869, 0.588210293, 0.584624754, 0.447023634, 0.577406114, 0.599080925, 0.338233778, 0.935787187, 0.767922816, 0.730707541, 9, 4, 34, 865, 231, 0.967715438, 2212771, 1575344},
  {'NM', 5, 271197, 380413, 29280, 652945, 172905, 0.675665529, 0.529339862, 0.463728433, 0.408346083, 0.316473876, 0.605092966, 0.309249937, 0.909146217, 0.668956867, 0.663488137, 3, 2, 35, 309, 385, 0.882430156, 400150, 319348},
  {'NY', 29, 3756095, 4846500, 1999140, 2032115, 1133665, 0.70286462, 0.49245313, 0.552046847, 0.471839176, 0.346782547, 0.636017675, 0.370316435, 0.956790499, 0.804318063, 0.780079998, 9, 5, 36, 838, 168, 0.954871079, 4696564, 2785300},
  {'NC', 15, 1882387, 3391468, 1661210, 333900, 353605, 0.764877439, 0.5841265, 0.651179135, 0.485645063, 0.458818158, 0.473878286, 0.24481483, 0.917961349, 0.615042765, 0.633628295, 7, 2, 37, 808, 349, 0.959599325, 2362721, 2463937},
  {'ND', 3, 160333, 342742, 12345, 16575, 37575, 0.675012656, 0.538425241, 0.463820636, 0.396731516, 0.361131101, 0.390590432, 0.214263665, 0.89506844, 0.629496735, 0.643369996, 4, 5, 38, 426, 97, 0.900981523, 99801, 218809},
  {'OH', 18, 2187368, 5112592, 1038960, 242550, 280235, 0.740306123, 0.551902727, 0.633838504, 0.544565232, 0.356963316, 0.453506763, 0.339443667, 0.931183233, 0.729199328, 0.682312882, 7, 4, 39, 720, 250, 0.952064015, 2469792, 2861383},
  {'OK', 7, 579511, 1476819, 208140, 169025, 417190, 0.660992862, 0.474338342, 0.502656523, 0.285535826, 0.381542973, 0.316863388, 0.152535372, 0.87714238, 0.591658886, 0.570074444, 3, 1, 40, 477, 377, 0.942163289, 439276, 956239},
  {'OR', 7, 922073, 1639352, 53370, 241285, 237110, 0.719218362, 0.589694129, 0.5505868, 0.511746672, 0.48045008, 0.708415161, 0.424041347, 0.96616192, 0.763455381, 0.749616044, 1, 4, 41, 97, 134, 0.890390825, 1087711, 808800},
  {'PA', 20, 2670125, 5229370, 992635, 523430, 355175, 0.748743561, 0.546101714, 0.643283551, 0.5066465, 0.581158343, 0.553486106, 0.333498025, 0.951298453, 0.778767633, 0.729729281, 8, 4, 42, 806, 221, 0.956026479, 3023372, 2941320},
  {'RI', 4, 238316, 392884, 41755, 89200, 35715, 0.703965787, 0.506138812, 0.511636049, 0.439497607, 0.423176166, 0.65941913, 0.45291799, 0.957680458, 0.768147719, 0.768017355, 11, 4, 44, 904, 183, 0.932561105, 262857, 179410},
  {'SC', 9, 871090, 1734790, 1020735, 111475, 103780, 0.680818919, 0.488453684, 0.596883346, 0.434445258, 0.412758069, 0.300274153, 0.138454571, 0.922189291, 0.630556622, 0.593915043, 8, 2, 45, 783, 394, 0.955634952, 913210, 1227596},
  {'SD', 3, 176520, 383470, 7035, 16265, 60450, 0.699438155, 0.517418561, 0.506089583, 0.435433573, 0.389322946, 0.416463196, 0.243941129, 0.904408009, 0.650731201, 0.672402966, 4, 4, 46, 430, 168, 0.932079023, 123465, 232560},
  {'TN', 11, 1155536, 2809339, 832175, 122210, 133955, 0.673522268, 0.449699171, 0.467149635, 0.195662275, 0.296629593, 0.379263106, 0.190894306, 0.891222007, 0.628333769, 0.620331237, 6, 2, 47, 670, 360, 0.954001865, 922433, 1571397},
  {'TX', 38, 3717051, 5709064, 2443170, 5633560, 1038520, 0.688387228, 0.49789419, 0.515698509, 0.36593897, 0.458013565, 0.378296223, 0.184639652, 0.886262903, 0.663410407, 0.669413152, 3, 0, 48, 444, 471, 0.954369811, 4295402, 4902528},
  {'UT', 6, 660353, 1090172, 19710, 181550, 110540, 0.498289145, 0.418568076, 0.436096819, 0.392710383, 0.282741042, 0.446261305, 0.265557687, 0.919416088, 0.70634662, 0.657479648, 2, 3, 49, 225, 266, 0.726569118, 346808, 549621},
  {'VT', 3, 180005, 288800, 4900, 8230, 13880, 0.668261734, 0.499915188, 0.52952999, 0.438395026, 0.405966216, 0.775311171, 0.545368787, 0.967323808, 0.804026823, 0.825987058, 10, 6, 50, 873, 134, 0.86852187, 182051, 94428},
  {'VA', 13, 1794836, 2384019, 1202890, 344060, 467780, 0.739281615, 0.565186281, 0.595711103, 0.599663275, 0.626332811, 0.566467372, 0.24755961, 0.918501589, 0.711732166, 0.714632414, 8, 3, 51, 809, 299, 0.940764407, 2099531, 1790421},
  {'WA', 12, 1568016, 2525529, 185110, 404615, 656645, 0.726996166, 0.589421722, 0.408814815, 0.41318026, 0.425708669, 0.702560636, 0.450950218, 0.96198325, 0.758384068, 0.770136576, 1, 5, 53, 128, 58, 0.892420836, 1886911, 1263779},
  {'WV', 5, 276913, 1060712, 53315, 17000, 22920, 0.650580705, 0.422898867, 0.497329819, 0.439877141, 0.415663093, 0.371198805, 0.199684391, 0.888827754, 0.625806538, 0.624247234, 7, 3, 54, 765, 284, 0.949074974, 190626, 481553},
  {'WI', 10, 1216918, 2564097, 252275, 179525, 168710, 0.773451179, 0.632983217, 0.4517567, 0.391981817, 0.495630995, 0.620496123, 0.383853905, 0.954195431, 0.71582395, 0.726360461, 6, 6, 55, 601, 169, 0.936199966, 1426784, 1405169},
  {'WY', 3, 111752, 268328, 2875, 29875, 19365, 0.651059854, 0.515382295, 0.44618346, 0.383142978, 0.365530305, 0.338973112, 0.146500891, 0.877430917, 0.596861212, 0.578120081, 3, 4, 56, 306, 187, 0.899602268, 56969, 173866},
  {'ME1', 1, 207042, 310103, 4465, 8525, 16140, 0.779428647, 0.658907115, 0.529856887, 0.453562835, 0.430530248, 0.711235348, 0.480522474, 0.950947039, 0.753727713, 0.724127533, 12, 9, 101, 919, 92, 0.930086967, 223138, 155712},
  {'ME2', 1, 123658, 373722, 3130, 5835, 14600, 0.721307213, 0.609772885, 0.49034584, 0.419740981, 0.398425917, 0.6125862, 0.376266688, 0.945780092, 0.742997137, 0.673647561, 12, 8, 102, 919, 92, 0.921686657, 147562, 179285},
  {'NE1', 1, 141323, 271452, 12245, 25910, 20720, 0.66994039, 0.548628043, 0.467287414, 0.3994228, 0.378746349, 0.465906603, 0.299003771, 0.910317534, 0.669349453, 0.671226414, 12, 7, 103, 438, 238, 0.915487399, 106036, 161462},
  {'NE2', 1, 173619, 203286, 42225, 29600, 17685, 0.713453485, 0.584261816, 0.497638056, 0.425365589, 0.403346188, 0.528125662, 0.35783693, 0.913332813, 0.675611503, 0.679456072, 12, 6, 104, 438, 238, 0.919892498, 140456, 142901},
  {'NE3', 1, 97379, 295756, 4580, 30355, 10410, 0.681599552, 0.558175972, 0.475419749, 0.406374068, 0.385337779, 0.289837784, 0.143407679, 0.887895396, 0.622783761, 0.58171263, 12, 5, 105, 438, 238, 0.935915136, 54857, 195099},
  {'US', 538, 57520321, 100294839, 29316860, 29683715, 16417105, 0.724446913, 0.545863005, 0.566335945, 0.448550193, 0.455574893, 0.53686871, 0.309348628, 0.921731514, 0.717326664, 0.732972545, 0, 0, 0, 0, 0, 0.942062453, 69678905, 64135805}
}

local NUM_STATES = 50
local NUM_DEMOGRAPHICS = 5
local NUM_ELECTORAL_COLLEGE_BODIES = 55

local states = ffi.new('state_t[?]', #state_data)
local usa

do -- Initialize states' tables
  for i, state in ipairs(state_data) do
    local new_state = make_state(unpack(state))
    states[i - 1] = new_state
    if ffi.string(new_state.name):lower() == 'us' then
      usa = new_state
    end
  end
end

local function biden_share(state, demographic, changes)
  local baseline = usa.bidenshare.underlying[demographic]
  local diff = changes.bidenshare.underlying[demographic]
  local state_bidenshare = state.bidenshare.underlying[demographic]

  if diff > baseline then
    return (((diff - baseline) / (1 - baseline)) *
           (1 - state_bidenshare)) +
           state_bidenshare
  else
    return (diff / baseline) * state_bidenshare
  end
end

local function turnout(state, demographic, changes)
  local baseline = usa.turnout.underlying[demographic]
  local diff = changes.turnout.underlying[demographic]
  local state_turnout = state.turnout.underlying[demographic]

  if diff > baseline then
    return (((diff - baseline) / (1 - baseline)) *
           (1 - state_turnout)) +
           state_turnout
  else
    return (diff / baseline) * state_turnout
  end
end

local function trump_vote(state, demographic, changes)
  return (1 - biden_share(state, demographic, changes)) *
         state.cvap.underlying[demographic] *
         turnout(state, demographic, changes)
end

local function tot_trump_vote(state, changes)
  local accumulator = 0

  for demographic = 0, NUM_DEMOGRAPHICS - 1 do
    accumulator = accumulator + trump_vote(state, demographic, changes)
  end

  return accumulator
end

local function nat_trump_vote(changes)
  local accumulator = 0

  for i = 0, NUM_STATES do
    accumulator = accumulator + tot_trump_vote(states[i], changes)
  end

  return accumulator
end

local function biden_vote(state, demographic, changes)
  return biden_share(state, demographic, changes) *
         state.cvap.underlying[demographic] *
         turnout(state, demographic, changes)
end

local function tot_biden_vote(state, changes)
  local accumulator = 0

  for demographic = 0, NUM_DEMOGRAPHICS - 1 do
    accumulator = accumulator + biden_vote(state, demographic, changes)
  end

  return accumulator
end

local function nat_biden_vote(changes)
  local accumulator = 0

  for i = 0, NUM_STATES do
    accumulator = accumulator + tot_biden_vote(states[i], changes)
  end

  return accumulator
end


local function agg_trump_share(state, changes)
  if (tot_biden_vote(state, changes) + tot_trump_vote(state, changes)) > 0 then
    return tot_trump_vote(state, changes) / (tot_biden_vote(state, changes) +
           tot_trump_vote(state, changes)) * state.other_offset
  else
    return 0
  end
end

local function agg_biden_share(state, changes)
  if (tot_biden_vote(state, changes) + tot_trump_vote(state, changes)) > 0 then
    return tot_biden_vote(state, changes) / (tot_biden_vote(state, changes) +
           tot_trump_vote(state, changes)) * state.other_offset
  else
    return 0
  end
end

local function nat_biden_share(changes)
  local biden_vote = nat_biden_vote(changes)
  return biden_vote / (biden_vote + nat_trump_vote(changes)) * usa.other_offset
end

local function nat_trump_share(changes)
  local trump_vote = nat_trump_vote(changes)
  return trump_vote / (trump_vote + nat_biden_vote(changes)) * usa.other_offset
end

local function biden_ev(changes)
  local evs = 0

  for i = 0, NUM_ELECTORAL_COLLEGE_BODIES do
    local state = states[i]

    if agg_biden_share(state, changes) > agg_trump_share(state, changes) then
      evs = evs + state.electoral_votes
    end
  end

  return evs
end

local function run_simulation(change_data)
  local changes = ffi.new('state_t')

  -- Initialize
  for i = 0, NUM_DEMOGRAPHICS - 1 do
    local biden_share = change_data.bidenshare.underlying[i + 1] / 1000
    changes.bidenshare.underlying[i] = biden_share

    local turnout = change_data.turnout.underlying[i + 1] / 1000
    changes.turnout.underlying[i] = turnout
  end

  local biden_evs = biden_ev(changes)
  local winner = biden_evs >= 269 and 'Biden' or 'Trump' -- Assumes house kept

  local biden_votes = nat_biden_vote(changes)
  local trump_votes = nat_trump_vote(changes)

  local pv_gap = biden_votes - trump_votes

  return {
    biden_evs = biden_evs,
    biden_votes = biden_votes,
    trump_votes = trump_votes,
    pv_gap = pv_gap,
    winner = winner
  }
end

return run_simulation

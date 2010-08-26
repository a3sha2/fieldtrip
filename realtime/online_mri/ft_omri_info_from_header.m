function S = ft_omri_info_from_header(hdr)
% function S = ft_omri_info_from_header(hdr)
%
% Convenience function to retrieve most important MR information
% from a given header (H) as retrieved from a FieldTrip buffer.
% Will look at both NIFTI-1 and SiemensAP fields, if present, and
% give preference to SiemensAP info.
%
% Returns empty array if no information could be found.
%
% (C) 2010 S. Klanke


SNif = [];
SSap = [];
if isfield(hdr,'nifti_1')
	try
		SNif = mri_info_from_nifti(hdr.nifti_1);
	catch
		warning('Errors occured while inspecting NIFTI-1 header.');
	end
end
if isfield(hdr,'siemensap')
	try
		SSap = mri_info_from_sap(hdr.siemensap);
	catch
		warning('Errors occured while inspecting SiemensAP header.');
	end
end
	
if ~isempty(SSap)
	S = SSap;
	if ~isempty(SNif)
		if ~isequal(SNif.voxels,SSap.voxels)
			warning('Conflicting information in NIFTI and SiemensAP - trusting SiemensAP...');
	    end
	end
else
	if ~isempty(SNif)
		S = SNif;
	else
		S = [];
	end
end


function S = mri_info_from_nifti(NH)

S.vx = double(NH.dim(1));
S.vy = double(NH.dim(2));
S.vz = double(NH.dim(3));
S.voxels = [S.vx S.vy S.vz];
S.voxdim = double(NH.pixdim(1:3));
S.size = S.voxels .* S.voxdim;
S.mat0 = [double([NH.srow_x; NH.srow_y; NH.srow_z]) ; 0 0 0 1];
S.numEchos = 1;	% can't detect this from NIFTI :-(

switch NH.slice_code
	% Long-term TODO: look at slice_start and slice_end for padded slices
	case 1	% NIFTI_SLICE_SEQ_INC  
		inds = 1:S.vz;
	case 2  % NIFTI_SLICE_SEQ_DEC
		inds = S.vz:-1:1;
	case 3  % NIFTI_SLICE_ALT_INC
		inds = [(1:2:S.vz) (2:2:S.vz)];
	case 4  % NIFTI_SLICE_ALT_DEC
		inds = [(S.vz:-2:1) ((S.vz-1):-2:1)];
	case 5  % NIFTI_SLICE_ALT_INC2
		inds = [(2:2:S.vz) (1:2:S.vz)];
	case 6  % NIFTI_SLICE_ALT_DEC2
		inds = [((S.vz-1):-2:1) (S.vz:-2:1)];
	otherwise
		warning('Unrecognized slice order - using default');
		inds = 1:S.vz;
end

if NH.slice_duration > 0
	S.TR = double(NH.slice_duration * S.vz);
	% first set up linear
	S.deltaT = (0:(S.vz-1))*double(NH.slice_duration) 
	% then re-shuffle
	S.deltaT(inds) = S.deltaT;
else
	% what can we do here?
	S.TR = 2;
	S.deltaT = (0:(S.vz-1))*S.TR/S.vz;
	S.deltaT(inds) = S.deltaT;
end

function S = mri_info_from_sap(SP)

phaseFOV   = SP.sSliceArray.asSlice{1}.dPhaseFOV;
readoutFOV = SP.sSliceArray.asSlice{1}.dReadoutFOV;
sliceThick = SP.sSliceArray.asSlice{1}.dThickness;
distFactor = SP.sGroupArray.asGroup{1}.dDistFact;
				
S.vx = double(SP.sKSpace.lBaseResolution);
S.vy = S.vx * phaseFOV / readoutFOV;
S.vz = double(SP.sSliceArray.lSize);
S.voxels = [S.vx S.vy S.vz];

% this only takes care of the scaling, not the proper orientation
sx = readoutFOV/S.vx;
sy = phaseFOV/S.vy;	% should always be == sx
sz = sliceThick * (1.0 + distFactor);

S.size = [readoutFOV  phaseFOV  S.vz*sz];
S.mat0 = [sx 0 0 0;  0 sy 0 0; 0 0 sz 0; 0 0 0 1];
S.voxdim = [sx sy sz];

S.numEchos = double(SP.lContrasts);
S.TR = double(SP.alTR) * 1e-6;  % originally in microseconds

switch SP.sSliceArray.ucMode
	case 1	% == NIFTI_SLICE_SEQ_INC  
		inds = 1:S.vz;
	case 2  % == NIFTI_SLICE_SEQ_DEC
		inds = S.vz:-1:1;
	case 4  % odd:ALT_INC or even:ALT_INC2
		if mod(S.vz,2) == 1
			inds = [(1:2:S.vz) (2:2:S.vz)];
		else
			inds = [(2:2:S.vz) (1:2:S.vz)];
		end
	otherwise
		warning('Unrecognized slice order - using default');
		inds = 1:S.vz;
end
% first set up linear
S.deltaT = (0:(S.vz-1))*S.TR/S.vz
% then re-shuffle
S.deltaT(inds) = S.deltaT;


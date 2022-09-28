//SC Phase
//Ziqing (Gary) Gong
//Oct 26 2021

(
s.freeAll;
ServerTree.removeAll;

s.newBusAllocators;
~reverbBus = Bus.audio(s, 2);
~reverbBus2 = Bus.audio(s,2);
~combNBus = Bus.audio(s,2);
~combLBus = Bus.audio(s,2);

~makeNoodes = {
	s.bind({
		~fxGroup = Group.new;
		~combN = Synth(\combN, [\in, ~combNBus, \out,~reverbBus ], ~fxGrp);
		~combL = Synth(\combL,[\in, ~combLBus, \out,~reverbBus], ~fxGrp);
		~reverb = Synth(\reverb, [\in, ~reverbBus,], ~fxGroup,addAction:\addToTail);
		~reverb2 = Synth(\reverb2, [\in, ~reverbBus2,], ~fxGroup,addAction:\addToTail);
	});
};

s.waitForBoot({

	Buffer.freeAll;

	~buf = Buffer.allocConsecutive(4,s,2048,1);

	~bufPath = PathName.new(thisProcess.nowExecutingPath).parentPath ++ "audio/";
	~guitarBuf = Buffer.read(s, ~bufPath ++ "GuitarVibrato.aiff");
	~pianoBuf = Buffer.read(s, ~bufPath ++ "PianoMute_DelayShortMN.wav");

	s.sync;


	//notes --> envs --> wavetables

	//b minor fugue WTC book 1
	~bmEnv =
	Env(
		[ 0, -4, -7, 1, 0, 5, 4, -2, -3, 6, 5, 0, -1, 8, 7, 6, 6, 3, 0, 2 ],
		[1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5,0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 2],
		{rrand(-20,20)}!19

	);
	~bMinorSig = ~bmEnv.asSignal(1024);
	~bMinor = ~bMinorSig.asWavetable;

	//~bmEnv.plot;
	~buf[0].loadCollection(~bMinor);
	//~buf[0].plot;

	//Eb major fugue WTC book 1

	~ebEnv =
	Env([-1, -4, -6, -4, -8, -3, -4, -3, 1, -1, -2, -6, 4, 3, 1, -1, 6, 3, -1, -3, 6, 3, -3],
		[0.25,0.25,0.25,0.25,0.25,0.25,0.25,0.5,0.5,1,0.25,0.25,0.5,0.5,1,0.25,0.25,0.25,0.25,0.25,0.25,0.25],
		{rrand(-15,15)}!22

	);

	~ebMajorSig = ~ebEnv.asSignal(1024);
	~ebMajor= ~ebMajorSig.asWavetable;

	~ebEnv.plot;
	~buf[1].loadCollection(~ebMajor);
	~buf[1].plot;

	//E major fugue WTC book 2
	~eMEnv =
	Env([-3, -1, 2, 1, -1, 4],
		[4, 2, 2, 2, 4],
		\sine
	);

	~eMajorSig = ~eMEnv.asSignal(1024);
	~eMajor= ~eMajorSig.asWavetable;

	//~eMEnv.plot;
	~buf[2].loadCollection(~eMajor);
	//~buf[2].plot;

	//D major fugue WTC book 2
	~dMEnv =
	Env(
		[7, 7, 7, 0, 4, -3, 2, 0, -1, -5],
		[0.5, 0.5, 1, 1.5, 0.5, 0.5, 0.5, 1, 1],
		{rrand(-25,25)}!9
	);

	~dMajorSig = ~dMEnv.asSignal(1024);
	~dMajor= ~dMajorSig.asWavetable;

	//~dMEnv.plot;
	~buf[3].loadCollection(~dMajor);
	//~buf[3].plot;

	//tunning
	~scale = Scale.chromatic(tuning:'just');


	//synths and effects
	SynthDef(\osc, {
		arg buf = ~buf[0], freq=200, detune=0.2,
		amp=0.2, pan=0, out=0, rout=0, rsend=(-20),
		atk=0.01, sus=1, rel=0.01, c0=1, c1= -1;
		var sig, env, detuneCtrl;
		env = EnvGen.ar(
			Env([0,1,1,0],[atk,sus,rel],[c0,0,c1]),
			doneAction:2
		);

		//array of eight Oscs with uniquely detune frequencies
		//and unique initial phase offsets
		detuneCtrl = LFNoise1.kr(0.1!4).bipolar(detune).midiratio;
		sig = Osc.ar(buf, freq * detuneCtrl, {Rand(0,2pi)}!4);

		sig = Splay.ar(sig); //spread 8 signals over stereo field
		sig = LeakDC.ar(sig); //remove DC bias
		sig = Balance2.ar(sig[0], sig[1], pan, amp); //L/R balance (pan)
		sig = sig * env;
		Out.ar(out, sig);
		Out.ar(rout, sig * rsend.dbamp); //"post-fader" send to reverb
	}).add;

	SynthDef(\reverb2, {
		arg in=0, out=0, dec=2, lpf=1500;
		var sig;
		sig = In.ar(in, 2).sum;
		sig = DelayN.ar(sig, 0.03, 0.03);
		sig = CombN.ar(sig, 0.1, {Rand(0.01,0.099)}!32, dec);
		sig = SplayAz.ar(2, sig);
		sig = LPF.ar(sig, lpf);
		5.do{sig = AllpassN.ar(sig, 0.1, {Rand(0.01,0.099)}!2, 3)};
		sig = LPF.ar(sig, lpf);
		sig = LeakDC.ar(sig);
		Out.ar(out, sig);
	}).add;

	SynthDef(\grain2, {
		var sig, env;
		env = Env.asr(\atk.ir(0.1), \sus.ir(1), \rel.ir(1)).kr(2,\gate.kr(1));
		sig = GrainBuf.ar(
			1,
			trigger: \trigger.kr(0.01),
			dur: \durG.kr(3),
			sndbuf:\buf.kr(0),
			rate:\rate.kr(0.5),
			pos: \pos.kr(0.5),
			interp:4,
			pan:\pan.kr(0),
		);

		sig = sig * env * \amp.kr(0.4);
		Out.ar(\out.kr(0),sig!2);
	}).add;


	SynthDef.new(\wt, {
		arg buf = ~buf[0], atk = 0.01, rel = 0.1, sus = 0.1;
		var mod, sig, env;
		env = EnvGen.ar(
			Env([0,1,1,0],[atk,sus,rel],[1,0,-1]),
			doneAction:2
		);
		sig = Osc.ar(buf,\freq.kr(333));
		sig = sig +BrownNoise.ar(0.007!2);
		sig = LPF.ar(sig,\cutfreq.kr(500));
		sig = Pan2.ar(sig,\pan.kr(0),\amp.kr(0.1));
		Out.ar(\out.kr(0),sig);
	}).add;

	SynthDef(\combN, {
		var sig, del;
		sig = In.ar(\in.kr(0),2);
		del = CombN.ar(sig,1,\del.kr(0.5), \dec.kr(5));
		sig = sig.blend(del,\mix.kr(0.4));
		Out.ar(\out.kr(0),sig);
	}).add;


	SynthDef(\combL, {
		var sig, del;
		sig = In.ar(\in.kr(0),2);
		del = CombL.ar(sig, 1, SinOsc.kr(0.1).exprange(0.01, 0.2),\dec.kr(4));
		sig = sig.blend(del,\mix.kr(0.4));
		Out.ar(\out.kr(0), sig);
	}).add;

	SynthDef(\reverb, {
		var sig, wet;
		sig = In.ar(\in.ir(0), 2);
		wet = GVerb.ar(sig.sum, 250, 4);
		wet = LPF.ar(wet, 1250);
		sig = sig.blend(wet,\mix.kr(0.2));
		Out.ar(\out.kr(0), sig);
	}).add;


	ServerTree.add(~makeNoodes);
	ServerTree.run;

	s.sync;

	~scale = Scale.chromatic(tuning:'just');

	s.sync;

	~amb1 = Pbind(
	\instrument,\grain2,
	\buf,~pianoBuf,
	//\trigger,0.25
	\out,~combNBus,
	\pos, Pwhite(0.3,0.8,inf),
	\rate, Pwhite(0.5,4,inf),
	\amp,Pwhite(0.1,0.5),
	\durG,Pseq([
		0.25,0.25,0.5,
		0.25,0.25,0.5,
		0.25,0.25,0.25,0.125,0.125,
		0.25,0.25,0.5
	] * 2,inf),
	\pan, Pwhite(-1.0,1.0,inf),
);


~amb2= Pbind(
		\instrument,\grain2,
		\trigger,[2,2.4],
		\buf, ~guitarBuf,
		\out,~combNBus,
		\pos, Pwhite(0.1,0.8,inf),
		\rate, [7.68/2, 7.68/4],
		\amp,Pshuf([0.4,0.01,0.3,0.02],inf),
		\durG,[0.8,6]
	);

~amb2var = Pbind(
		\instrument,\grain2,
		\trigger,[2,2.4],
		\buf, ~guitarBuf,
		\out,~combNBus,
		\pos, Pwhite(0.1,0.8,inf),
		\rate, [7.68/16, 7.68/8],
		\amp,Pshuf([0.4,0.01,0.3,0.02],inf),
		\durG,[0.8,6]
	);
//voice1

//1st motif
~omotif1 = Pbind(
	\instrument, \osc,
	\buf, ~buf[0],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([16, 15, 13, 15],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.001,0.0007,inf,inf)
);

~omotif1Rand = Pbind(
	\instrument, \osc,
	\buf, ~buf[0],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([16, 15, 13, 15],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

~omotif1Long = Pbind(
	\instrument, \osc,
	\buf, ~buf[0],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([16, 15, 13, 15],8),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus2,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

//2nd

~omotif2 = Pbind(
	\instrument, \osc,
	\buf, Prand(~buf[0..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([10, 15, 18, 17],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


~omotif2Rand = Pbind(
	\instrument, \osc,
	\buf, Prand(~buf[0..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([10, 15, 18, 17],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);



//voice 2
~tmotif1 = Pbind(
	\instrument, \osc,
	\buf, ~buf[2],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([15, 13, 16, 15],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

~tmotif1Rand = Pbind(
	\instrument, \osc,
	\buf, ~buf[2],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([15, 13, 16, 15],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

~tmotif1Long = Pbind(
	\instrument, \osc,
	\buf, ~buf[2],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([15, 13, 16, 15],8),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus2,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

//2nd
~tmotif2 = Pbind(
	\instrument, \wt,
	\buf, Prand(~buf[0..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.004, 0.009),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.1,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([10, 15, 18, 17],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


~tmotif2Rand = Pbind(
	\instrument, \osc,
	\buf, Prand(~buf[2..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([10, 15, 18, 17],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);




//voice 3
~rmotif1 = Pbind(
	\instrument, \osc,
	\buf, ~buf[1],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([8, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


~rmotif1Rand = Pbind(
	\instrument, \osc,
	\buf, ~buf[1],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([8, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

~rmotif1Long = Pbind(
	\instrument, \osc,
	\buf, ~buf[1],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([8, 11, 10, 11],8),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus2,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


//2nd
~rmotif2 = Pbind(
	\instrument, \wt,
	\buf, Prand(~buf[0..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.004, 0.009),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.1,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([15, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


~rmotif2Rand = Pbind(
	\instrument, \osc,
	\buf, Prand(~buf[0..1],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([15, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);



//voice 4

~fmotif1 = Pbind(
	\instrument, \osc,
	\buf, ~buf[3],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([8, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


~fmotif1Rand = Pbind(
	\instrument, \osc,
	\buf, ~buf[3],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([8, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

~fmotif1Long = Pbind(
	\instrument, \osc,
	\buf, ~buf[3],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([8, 11, 10, 11],8),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus2,
	\amp,Pwhite(0.01,0.05,inf,inf)
);


//2nd

~fmotif2 = Pbind(
	\instrument, \wt,
	\buf, Prand(~buf[0..3],4),
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.004, 0.009),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.1,
	\tuning,\just,
	\scale,~scale,
	\degree,Pseq([15, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.02,inf,inf)
);


~fmotif2Rand = Pbind(
	\instrument, \osc,
	\buf, ~buf[3],
	\dur, Pseq([0.25],inf),
	\atk,Pwhite(0.001, 0.004),
	\sus,Pwhite(0.05, 0.08),
	\rel,0.002,
	\tuning,\just,
	\scale,~scale,
	\degree,Pshuf([15, 11, 10, 11],4),
	\pan,Pwhite(-0.9,0.9,inf),
	\out,~reverbBus,
	\amp,Pwhite(0.01,0.05,inf,inf)
);

t = TempoClock.new(90/60).permanent_(true);

});
)


~bmEnv.plot;
~buf[0].plot;

//performing the piece

~playAMB1 = ~amb1.play;
~playAMB1.stop;

(
~m1ori = Ptpar(
	[
//1
0, Pn(~omotif1,10),
//2
8,Pn(~tmotif1, 10),
//3
16,      Pn(~rmotif1, 10),
//4
24,        Pn(~fmotif1, 10),
],1).play(t,quant:1);
)

(
~m1var = Ptpar(
	[
//1
0,Pn(~omotif1Long,10),
0, Pn(~omotif1Rand,15),
//2
8,   Pn(~tmotif1Rand, 15),
//3
16,Pn(~tmotif1Long,10),
16,    Pn(~rmotif1Rand, 15),
//4
24,        Pn(~fmotif1Rand, 15),
32, Pn(~rmotif1Long,10),
],1).play(t,quant:1);
)


(
~m2ori = Ptpar(
	[
//1
0,Pn(~fmotif1Long,10),
0, Pn(~omotif2,20),
//2
8,   Pn(~tmotif2, 20),
//3
16,Pn(~fmotif1Long,5),
16,    Pn(~rmotif2d, 20),
24, Pn(~rmotif1Long,10),
//4
24,        Pn(~fmotif2, 20),
36, Pn(~rmotif1Long,5),
],1).play(t,quant:1);
)

(
~m2var = Ptpar(
	[
//1
0, Pn(~fmotif2Rand,20),
//2
8,   Pn(~rmotif2Rand, 20),
//3
16,Pn(~tmotif2Rand,5),
16,    Pn(~rmotif2d, 20),
//4
24,        Pn(~omotif2Rand, 20),
36, Pn(~rmotif1Long,5),
],1).play(t,quant:1);
)

(
~m1prime = Ptpar(
	[
	//1
0, Pn(~omotif1,10),
//2
8, Pn(~omotif1Long,4),
8,Pn(~tmotif1Rand, 10),
//3
16,      Pn(~rmotif1, 10),
//4
20,Pn(~omotif1,10),
24,        Pn(~fmotif1Rand, 8),
],1).play(t,quant:1);
)


~playAMB2 = ~amb2.play;
~playAMB2.stop;
~playAMB2VAR = ~amb2var.play;
~playAMB2VAR.stop;






// //chord testing for capstone
//
// ~testchords = Pbind(
// 	\instrument, \osc,
// 	\buf, ~buf[0],
// 	\dur, Pseq([0.25],inf),
// 	\atk,Pwhite(0.001, 0.004),
// 	\sus,Pwhite(0.05, 0.08),
// 	\rel,0.002,
// 	\tuning,\just,
// 	\scale,~scale,
// 	\degree,Pshuf([16, 15, 13, 15],8),
// 	\pan,Pwhite(-0.9,0.9,inf),
// 	\out,~reverbBus2,
// 	\amp,Pwhite(0.01,0.05,inf,inf)
// );








//
//  ContentView.swift
//  convCalculator
//
//  Created by peiyu on 2021/4/23.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var hClass
    @ObservedObject var calc:calculator
    @State var cat:String
    @State var unit:String
    @State var catChangingUnit:Bool = false

    var textMemory:String {
        if let m = calc.valueMemory {
            return "m = " + calc.outputText(m)
        } else {
            return ""
        }
    }
    var pickerHeight:CGFloat {
        62 + calc.cgByClass([8,16])
    }
    var body: some View {
        GeometryReader { g in
            VStack (spacing:0) {
                VStack (spacing:calc.cgByClass([4,8])) {
                    HStack {
                        categoryPicker(calc:calc, cat:$cat, unit:$unit)
                            .padding(.horizontal)
                        Spacer()
                    }
                    HStack {
                        unitPicker(calc: calc, cat: $cat, unit: $unit)
                            .padding(.horizontal)
                        Spacer()
                    }
                } //度量區
                .frame(height: pickerHeight, alignment: .bottomLeading)
                .padding(.bottom, calc.cgByClass([4,8]))
                
                let ratioDisplay:CGFloat = calc.cgByClass([1.6]) / 5
                let ratioLog:CGFloat = ratioDisplay * calc.cgByClass([0.9,0.7]) / 5
                let ratioOutput:CGFloat = ratioDisplay * calc.cgByClass([2.9,3.3]) / 5
                let ratioMemory:CGFloat = ratioDisplay * calc.cgByClass([1.2,1]) / 5
                let ratioButtom:CGFloat = calc.cgByClass([3.4]) / 5
                VStack (spacing:0) { //輸出區
                    HStack { //===== Log =====
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    Spacer()
                                    Text(calc.logText)
                                        .foregroundColor(Color(.darkGray))
                                        .font(.system(size: (g.size.height - pickerHeight) * ratioLog))
                                        .minimumScaleFactor(calc.cgByClass([0.5]))
                                        .padding(.horizontal)
                                        .lineLimit(1)
                                        .id("logText")
                                }
                                .frame(minWidth: g.size.width, alignment: .trailing)
                            } //ScrollView
                            .onChange(of: calc.logText) {_ in
                                withAnimation {
                                    proxy.scrollTo("logText", anchor: .trailing)
                                }
                            } //onChange
                        } //ScrollViewReader
                    } //HStack
                    .frame(width:g.size.width, height: (g.size.height - pickerHeight) * ratioLog, alignment: .top)
                    
                    HStack { //===== Output =====
                        Spacer()
                        Text(calc.textCurrent)
                            .font(.custom("System", size: (g.size.height - pickerHeight)  * ratioOutput))
                            .minimumScaleFactor(calc.cgByClass([0.4,0.3]))
                            .lineLimit(1)
                            .padding(.horizontal)
                    }
                    .frame(width:g.size.width, height: (g.size.height - pickerHeight)  * ratioOutput, alignment: .trailing)
                    
                    HStack { //===== Memory =====
                        Text(textMemory)
                            .foregroundColor(Color.brown)
                            .font(.system(size: (g.size.height - pickerHeight) * ratioMemory))
                            .minimumScaleFactor(calc.cgByClass([0.5]))
                            .padding(.horizontal)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .frame(width:g.size.width, height: (g.size.height - pickerHeight) * ratioMemory, alignment: .bottomLeading)
                } //VStack 輸出區
                .frame(width:g.size.width, height: (g.size.height - pickerHeight)  * ratioDisplay, alignment: .topTrailing)
                .background(Color(.lightGray))
                    
                VStack (spacing: 0) {
                    buttons(calc: calc)
                        .padding(.horizontal,calc.cgByClass([8,0]))
                    
                }   //VStack 按鈕區
                .frame(width: g.size.width, height: (g.size.height - pickerHeight) * ratioButtom, alignment: .bottom)
            }   //VStack
            .frame(width: g.size.width, height: g.size.height)
        } //Geometry
    } //body
}

struct buttons: View {
    @ObservedObject var calc:calculator
//    @Binding var output:String
    let compactLabel:[[String]] = [["C","mc","mr","ms"],
                                ["7","8","9","/"],
                                ["4","5","6","*"],
                                ["1","2","3","-"],
                                ["0",".","=","+"]]
    let wideLabel:[[String]] = [["C","十億","十萬","7","8","9","/","CE"],
                             ["mc","百億","百萬","4","5","6","*","∛"],
                             ["mr","千億","千萬","1","2","3","-","√"],
                             ["ms", "兆", "億", "0",".","=","+","x²"]]
    let regularPadLabel:[[String]] = [["C","mc","mr","ms","CE"],
                                   ["7","8","9","/","x³"],
                                   ["4","5","6","*","∛"],
                                   ["1","2","3","-","√"],
                                   ["0",".","=","+","x²"]]
    let systemImageName:[String:String] = ["*":"multiply", "/":"divide", "+":"plus", "-":"minus", "=":"equal"]
    var bLabel:[[String]] {
        switch calc.widthClass {
        case .regularPad:
            return regularPadLabel
        case .widePad, .widePhone:
            return wideLabel
        default:
            return compactLabel
        }
    }

    var body: some View {
        GeometryReader { g in
            let vw = (g.size.width - calc.cgByClass([60,80,60])) / CGFloat(bLabel[0].count)
            let vh = (g.size.height - calc.cgByClass([80,60])) / CGFloat(bLabel.count)
            VStack {
                ForEach(bLabel, id:\.self){ row in
                    HStack{
                        Spacer()
                        ForEach(row, id:\.self) { labelText in
                            let narrowWidth:Bool = labelText.count > 1 || calc.opBasic[labelText] != nil || labelText == "=" || calc.power10[labelText] != nil
                            let fontSize = vh * (narrowWidth ? calc.cgByClass([0.8,0.6]) : 1)
                            Button(action: {
                                calc.keyin(labelText,  byUser: true)
                            }, label: {
                                if let imageName = systemImageName[labelText] {
                                    Image(systemName: imageName)
                                        .padding()  //padding不能放到外面以免按鈕空白處按了無反應
                                } else {
                                    Text(labelText == "." ? "•" : labelText)
                                        .padding()
                                }
                            })
                            .font(.custom("System", size: fontSize))
                            .minimumScaleFactor(0.7)
                            .frame(width: vw , height: vh, alignment: .center)
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.blue, lineWidth: 1))
                            .disabled((calc.textCurrent.contains(".") && calc.valueInput != nil && labelText == ".")
                                || (calc.power10[calc.textLastKey] != nil && (calc.power10[labelText] != nil || calc.digits.contains(labelText)))
                                || (calc.opBasic[calc.textLastKey] != nil && (calc.opBasic[labelText] != nil || calc.opStrong.contains(labelText) || labelText == "="))
                                || (calc.valueMemory == nil && (labelText == "mc" || labelText == "mr"))
                                || ((calc.outputText(calc.valueCurrent).count >= calc.outputLength || calc.textCurrent.count >= calc.sigfig) && calc.valueInput != nil && calc.digits.contains(labelText)))
                        }
                        Spacer()
                    }
                }   //ForEach
            }   //VStack
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

struct icon: View {
    var body: some View {
        VStack{
            HStack {
                Spacer()
                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
                    Image(systemName: "multiply")
                })
                .frame(width: 300, height: 300, alignment: .center)
                .overlay(RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.blue, lineWidth: 1))

                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
                    Image(systemName: "divide")
                })
                .frame(width: 300, height: 300, alignment: .center)
                .overlay(RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.blue, lineWidth: 1))
                Spacer()
            }
            .padding(.bottom, 2)
            HStack {
                Spacer()
                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
                    Image(systemName: "plus")
                })
                .frame(width: 300, height: 300, alignment: .center)
                .overlay(RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.blue, lineWidth: 1))
                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/, label: {
                    Image(systemName: "minus")
                })
                .frame(width: 300, height: 300, alignment: .center)
                .overlay(RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.blue, lineWidth: 1))
                Spacer()

            }
         }
        .font(.custom("System", size: 200))
    }

}

struct categoryPicker:View {
    @ObservedObject var calc:calculator
    @Binding var cat:String
    @Binding var unit:String

    var body: some View {
        VStack {
            Picker("", selection: $cat) {
                ForEach(calc.cats, id:\.self) {c in
                    Text(c).tag(c)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .labelsHidden()
            .fixedSize()
            .onReceive([cat].publisher.first()) { value in
                if cat != calc.cat {
                    if let c = calc.units[cat] {
                        unit =  c[0]
                    }
                }
            }
        }
     }
    
    
}

struct unitPicker:View {
    @ObservedObject var calc:calculator
    @Binding var cat:String
    @Binding var unit:String
    
    var units:[String] {
        let u:[String] = calc.units[cat] ?? []
        switch calc.widthClass {
        case .compact:
            return Array(u[0..<6])
        default:
            return u
        }
    }
    var body: some View {
        Picker("", selection: $unit) {
            ForEach(units, id:\.self) {u in
                Text(u).tag(u)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .labelsHidden()
        .fixedSize()
        .onReceive([unit].publisher.first()) { value in
            calc.unitConvert(pickerCat:cat,pickerUnit:value)
        }
        .disabled(cat == "貨幣" && calc.currencyTime == nil)

    }
    
    
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        let calc: calculator = calculator()
//        ContentView(calc: calc, cat: calc.cats[0], unit: (calc.units[calc.cats[0]] ?? [])[0])
//        ContentView(calc: calc, cat: calc.cats[0], unit: (calc.units[calc.cats[0]] ?? [])[0])
//            .previewInterfaceOrientation(.landscapeLeft)
//    }
//}

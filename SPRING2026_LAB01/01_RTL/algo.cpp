#include<iostream>
#include<vector>
#include<algorithm>
#include<fstream>
using namespace std;

struct Shape
{
    int layer, llx, lly, urx, ury;
};

void read_testcase(vector<Shape> shapes, ifstream& infile, int drc_sel)
{
    for(int i=0;i<16;i++)
    {
        // typ llx lly urx ury
        infile >> shapes[i].layer >> shapes[i].llx >> shapes[i].lly >> shapes[i].urx >> shapes[i].ury;
    }
}

void solve_violations(vector<Shape> shapes)
{
    // solve the violations here
    vector<bool> same_layer(16, false);
}

int main(int argc, char** argv)
{
    ifstream infile(argv[1]);
    int num_pat, golden, drc_sel;
    vector<Shape> shapes(16);

    infile >> num_pat;
    cout << num_pat << " Patterns" << endl;
    for(int i=0;i<num_pat;i++)
    {
        infile >> golden >> drc_sel;
        // cout << "Pattern " << i+1 << ": golden = " << golden << ", drc_sel = " << drc_sel << endl;
        read_testcase(shapes, infile, drc_sel);
        // solve the violations here
        solve_violations(shapes);
    }
}